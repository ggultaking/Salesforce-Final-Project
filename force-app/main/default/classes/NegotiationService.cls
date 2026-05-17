public class NegotiationService {

    public static void submitCounterOffer(
        Id offerId,
        Decimal amount,
        String conditions,
        Date deadline
    ) {

        if (offerId == null) return;

        Negotiation__c n = new Negotiation__c(
            Offer__c = offerId,
            Amount__c = amount,
            Conditions_Changed__c = conditions,
            Response_Deadline__c = deadline,
            Status__c = 'Pending',
            Proposed_By__c = 'Buyer',
            Round_Number__c = 1
        );

        insert n;
    }
    public static void acceptOffer(Id offerId) {

    Offer__c o = [
        SELECT Id, Property__c
        FROM Offer__c
        WHERE Id = :offerId
        LIMIT 1
    ];

    o.Status__c = 'Accepted';
    update o;
}
public static void rejectOffer(Id offerId, String reason) {

    Offer__c o = [
        SELECT Id
        FROM Offer__c
        WHERE Id = :offerId
        LIMIT 1
    ];

    o.Status__c = 'Rejected';
    update o;
}
}