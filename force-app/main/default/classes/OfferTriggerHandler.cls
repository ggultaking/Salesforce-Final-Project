public class OfferTriggerHandler {

    // Recursion qoruması
    private static Boolean transactionAlreadyCreated = false;

    // =========================
    // BEFORE INSERT
    // =========================
    public static void beforeInsert(List<Offer__c> newOffers) {
        Set<Id> propertyIds = new Set<Id>();
        for (Offer__c o : newOffers) {
            if (o.Property__c != null) propertyIds.add(o.Property__c);
        }

        Map<String, Offer__c> activeOffers = new Map<String, Offer__c>();
        for (Offer__c o : [
            SELECT Buyer__c, Property__c
            FROM Offer__c
            WHERE Property__c IN :propertyIds
              AND Status__c = 'Active'
        ]) {
            activeOffers.put(o.Property__c + '-' + o.Buyer__c, o);
        }

        Map<Id, Property__c> props = new Map<Id, Property__c>([
            SELECT Id, Asking_Price__c
            FROM Property__c
            WHERE Id IN :propertyIds
        ]);

        for (Offer__c o : newOffers) {
            if (o.Status__c != 'Active') continue;
            if (o.Property__c == null || o.Buyer__c == null) continue;

            String key = o.Property__c + '-' + o.Buyer__c;
            if (activeOffers.containsKey(key)) {
                o.addError('Same buyer already has an active offer.');
            }

            Property__c p = props.get(o.Property__c);
            if (p != null && p.Asking_Price__c != null &&
                o.Offer_Amount__c < p.Asking_Price__c * 0.7) {
                o.addError('Offer must be at least 70% of asking price.');
            }
        }
    }

    // =========================
    // AFTER UPDATE
    // =========================
    public static void afterUpdate(
        List<Offer__c> newOffers,
        Map<Id, Offer__c> oldMap
    ) {
        // Recursion qoruması — rejectOtherOffers() update-i bizi yenidən buraya gətirir
        // amma o zaman heç bir offer 'Accepted'-ə keçmir, ona görə
        // acceptedOfferIds boş olacaq. Bəs Countered → triggered yenidən?
        // Aşağıda status check-lərlə idarə edirik.

        Set<Id> acceptedOfferIds    = new Set<Id>();
        Set<Id> revertedPropertyIds = new Set<Id>();

        for (Offer__c o : newOffers) {
            Offer__c old = oldMap.get(o.Id);
            if (old == null) continue;

            // Yenicə Accepted oldu (əvvəl Accepted deyildi)
            if (o.Status__c == 'Accepted' && old.Status__c != 'Accepted') {
                acceptedOfferIds.add(o.Id);
            }

            // Yenicə Countered oldu
            if (o.Status__c == 'Countered' && old.Status__c != 'Countered') {
                OfferDomainService.handleCounterOffer(o);
            }

            // Reject / Expire / Withdraw — property-ni revert et
            if ((o.Status__c == 'Rejected'  ||
                 o.Status__c == 'Expired'   ||
                 o.Status__c == 'Withdrawn') &&
                 old.Status__c != o.Status__c) {
                revertedPropertyIds.add(o.Property__c);
            }
        }

        if (!acceptedOfferIds.isEmpty() && !transactionAlreadyCreated) {
            transactionAlreadyCreated = true; // Eyni transaction-da ikinci dəfə işləməsin

            // 1. Digər active offer-ları reject et
            rejectOtherOffers(acceptedOfferIds);

            // 2. Transaction yarat — final sale price Negotiation-dan gəlir
// TransactionService.createTransaction(acceptedOfferIds, new Map<Id, Decimal>());
            // 3. Property-ni 'Under Contract' et və gizlət
            updatePropertyStatus(acceptedOfferIds);

            // 4. Property Match-i 'Under Contract' et
            hidePropertyMatches(acceptedOfferIds);
        }

        if (!revertedPropertyIds.isEmpty()) {
            OfferService.revertPropertyIfNoActiveOffers(revertedPropertyIds);
        }
    }

    // =========================
    // REJECT OTHER OFFERS
    // =========================
    private static void rejectOtherOffers(Set<Id> acceptedOfferIds) {
        Map<Id, Id> offerToProperty = new Map<Id, Id>();
        for (Offer__c o : [
            SELECT Id, Property__c
            FROM Offer__c
            WHERE Id IN :acceptedOfferIds
        ]) {
            offerToProperty.put(o.Id, o.Property__c);
        }

        Set<Id> propertyIds = new Set<Id>(offerToProperty.values());

        List<Offer__c> toReject = new List<Offer__c>();
        for (Offer__c o : [
            SELECT Id, Status__c
            FROM Offer__c
            WHERE Property__c IN :propertyIds
              AND Id NOT IN :acceptedOfferIds
              AND Status__c IN ('Active', 'Submitted', 'Countered')
        ]) {
            o.Status__c = 'Rejected';
            toReject.add(o);
        }

        if (!toReject.isEmpty()) {
            // Bu update OfferTrigger-i yenidən işlədir
            // amma transactionAlreadyCreated = true olduğu üçün
            // və heç biri 'Accepted'-ə keçmədiyi üçün Transaction yaranmır
            update toReject;
        }
    }

    // =========================
    // PROPERTY STATUS → UNDER CONTRACT + GİZLƏT
    // =========================
   // updatePropertyStatus metodunu dəyiş:
private static void updatePropertyStatus(Set<Id> acceptedOfferIds) {
    Set<Id> propertyIds = new Set<Id>();
    for (Offer__c o : [
        SELECT Property__c FROM Offer__c WHERE Id IN :acceptedOfferIds
    ]) {
        propertyIds.add(o.Property__c);
    }

    if (propertyIds.isEmpty()) return;

    List<Property__c> props = [
        SELECT Id, Status__c
        FROM Property__c
        WHERE Id IN :propertyIds
    ];

    for (Property__c p : props) {
        p.Status__c = 'Under Contract'; // Is_Visible__c yoxdur, yalnız status
    }

    if (!props.isEmpty()) update props;
}
    // =========================
    // HIDE PROPERTY MATCHES
    // =========================
    private static void hidePropertyMatches(Set<Id> acceptedOfferIds) {
        List<Offer__c> offers = [
            SELECT Id, Property__c, Buyer__c
            FROM Offer__c
            WHERE Id IN :acceptedOfferIds
        ];

        if (offers.isEmpty()) return;

        Set<Id> propertyIds = new Set<Id>();
        Set<Id> buyerIds    = new Set<Id>();
        for (Offer__c o : offers) {
            propertyIds.add(o.Property__c);
            buyerIds.add(o.Buyer__c);
        }

        List<Property_Match__c> matches = [
            SELECT Id, Status__c
            FROM Property_Match__c
            WHERE Property__c IN :propertyIds
              AND Status__c   != 'Under Contract'
        ];

        for (Property_Match__c pm : matches) {
            pm.Status__c = 'Under Contract';
        }

        if (!matches.isEmpty()) update matches;
    }
}