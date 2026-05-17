public class OfferTriggerHandler {

    // =========================
    // BEFORE INSERT
    // =========================

public static void beforeInsert(List<Offer__c> newOffers) {

    Set<Id> propertyIds = new Set<Id>();

    for (Offer__c o : newOffers) {
        if (o.Property__c != null) {
        propertyIds.add(o.Property__c);
    }
    }

    Map<String, Offer__c> activeOffers = new Map<String, Offer__c>();

    for (Offer__c o : [
        SELECT Buyer__c, Property__c
        FROM Offer__c
        WHERE Property__c IN :propertyIds
        AND Status__c = 'Active'
    ]) {
        activeOffers.put(
    o.Property__c + '-' + o.Buyer__c,
    o
);
    }

    Map<Id, Property__c> props = new Map<Id, Property__c>([
        SELECT Id, Asking_Price__c
        FROM Property__c
        WHERE Id IN :propertyIds
    ]);

    for (Offer__c o : newOffers) {

        if (o.Property__c == null || o.Buyer__c == null) {
    continue;
}
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
    // BEFORE UPDATE (optional safe hook)
    // =========================
    public static void beforeUpdate(List<Offer__c> newOffers) {
        // currently not needed
    }

    // =========================
    // AFTER UPDATE
    // =========================
    public static void afterUpdate(
        List<Offer__c> newOffers,
        Map<Id, Offer__c> oldMap
    ) {

        Set<Id> acceptedOffers = new Set<Id>();
        Set<Id> revertedPropertyIds = new Set<Id>();

        for (Offer__c o : newOffers) {

            Offer__c old = oldMap.get(o.Id);

            if (old == null) continue;

            // =========================
            // ACCEPTED
            // =========================
            if (o.Status__c == 'Accepted' && old.Status__c != 'Accepted') {
                
                acceptedOffers.add(o.Id);
                List<Offer__c> offersToReject = new List<Offer__c>();

for (Offer__c other : [
    SELECT Id, Status__c
    FROM Offer__c
    WHERE Property__c = :o.Property__c
    AND Id != :o.Id
    AND Status__c = 'Active'
]) {
    other.Status__c = 'Rejected';
    offersToReject.add(other);
}

if (!offersToReject.isEmpty()) {
    update offersToReject;
}
            }
            // COUNTER OFFER / NEGOTIATION HOOK
if (o.Status__c == 'Countered' && old.Status__c != 'Countered') {

   OfferDomainService.handleCounterOffer(o);
}

            // =========================
            // REJECT / EXPIRE / WITHDRAW
            // =========================
            if ((o.Status__c == 'Rejected' ||
                 o.Status__c == 'Expired' ||
                 o.Status__c == 'Withdrawn') &&
                 old.Status__c != o.Status__c) {

                revertedPropertyIds.add(o.Property__c);
            }
        }

        // =========================
        // TRANSACTION CREATE
        // =========================
       
    if (!acceptedOffers.isEmpty()) {
    OfferDomainService.handleAcceptedOffer(acceptedOffers);
} 

        // =========================
        // PROPERTY REVERT LOGIC
        // =========================
        if (!revertedPropertyIds.isEmpty()) {
            OfferService.revertPropertyIfNoActiveOffers(revertedPropertyIds);
        }
    }
}