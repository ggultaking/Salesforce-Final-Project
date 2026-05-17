public class OfferDomainService {

    public static void handleAcceptedOffer(Set<Id> offerIds) {

        if (offerIds == null || offerIds.isEmpty()) return;

        List<Offer__c> offers = [
            SELECT Id, Property__c, Buyer__c
            FROM Offer__c
            WHERE Id IN :offerIds
        ];

        TransactionService.createTransaction(offerIds);
    }

    public static void handleRejectedOffer(Offer__c o) {
        // future logic
    }

    public static void handleCounterOffer(Offer__c o) {
        NegotiationService.submitCounterOffer(
            o.Id,
            o.Offer_Amount__c,
            '',
            Date.today().addDays(3)
        );
    }
}