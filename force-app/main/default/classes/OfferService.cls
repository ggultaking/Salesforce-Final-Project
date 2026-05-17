public class OfferService {
    

    public static void revertPropertyIfNoActiveOffers(Set<Id> propertyIds) {

        if (propertyIds == null || propertyIds.isEmpty()) return;

        // check active offers
        List<Offer__c> activeOffers = [
            SELECT Id, Property__c
            FROM Offer__c
            WHERE Property__c IN :propertyIds
            AND Status__c = 'Active'
        ];

        Set<Id> stillActive = new Set<Id>();

        for (Offer__c o : activeOffers) {
            stillActive.add(o.Property__c);
        }

        // properties with NO active offers
        List<Property__c> toUpdate = [
            SELECT Id, Status__c
            FROM Property__c
            WHERE Id IN :propertyIds
        ];

        for (Property__c p : toUpdate) {
          if (!stillActive.contains(p.Id)
    && p.Status__c != 'Available') {

    p.Status__c = 'Available';
}
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }
}