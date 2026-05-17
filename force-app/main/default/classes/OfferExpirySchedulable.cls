global class OfferExpirySchedulable implements Schedulable {

    global void execute(SchedulableContext sc) {

        List<Offer__c> offersToExpire = [
            SELECT Id, Status__c
            FROM Offer__c
            WHERE Status__c = 'Active'
            AND Expiry_Date__c < :Date.today()
        ];

        for (Offer__c o : offersToExpire) {
            o.Status__c = 'Expired';
        }

        if (!offersToExpire.isEmpty()) {
            update offersToExpire;
        }
    }
}