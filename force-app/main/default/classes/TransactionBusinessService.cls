public class TransactionBusinessService {

   public static void handleAfterUpdate(
    List<Transaction__c> newRecords,
    Map<Id, Transaction__c> oldMap
) {
    Set<Id> closedOfferIds = new Set<Id>();

    for (Transaction__c t : newRecords) {
        Transaction__c old = oldMap.get(t.Id);
        if (old == null) continue;

        // Yenicə Closed oldu
        if (t.Status__c == 'Closed' && old.Status__c != 'Closed') {
            if (t.Offer__c != null) closedOfferIds.add(t.Offer__c);
        }
    }

    if (!closedOfferIds.isEmpty()) {
        markMatchesSold(closedOfferIds);
    }
}

private static void markMatchesSold(Set<Id> offerIds) {
    // Offer-lərdən property və buyer tap
    List<Offer__c> offers = [
        SELECT Property__c, Buyer__c
        FROM Offer__c
        WHERE Id IN :offerIds
    ];

    if (offers.isEmpty()) return;

    Set<Id> propertyIds = new Set<Id>();
    for (Offer__c o : offers) propertyIds.add(o.Property__c);

    // Property Match → Sold
    List<Property_Match__c> matches = [
        SELECT Id, Status__c
        FROM Property_Match__c
        WHERE Property__c IN :propertyIds
          AND Status__c = 'Under Contract'
    ];

    for (Property_Match__c pm : matches) {
        pm.Status__c = 'Closed';
    }

    if (!matches.isEmpty()) update matches;

    // Property → Sold
    List<Property__c> props = [
        SELECT Id, Status__c
        FROM Property__c
        WHERE Id IN :propertyIds
    ];

    for (Property__c p : props) {
      p.Status__c          = 'Sold';
    p.Commission_Rate__c = 3.0; // ✅
        p.Sold_Date__c       = Date.today(); // ✅

        
    }

    if (!props.isEmpty()) update props;
}
}