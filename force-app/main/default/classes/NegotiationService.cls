public class NegotiationService {

   public static void submitCounterOffer(
    Id offerId,
    Decimal amount,
    String conditions,
    Date deadline
) {
    if (offerId == null) return;

    // Mövcud round sayını tap
    AggregateResult ar = [
        SELECT COUNT(Id) cnt
        FROM Negotiation__c
        WHERE Offer__c = :offerId
    ];
    Integer nextRound = (Integer)ar.get('cnt') + 1;

    Negotiation__c n = new Negotiation__c(
        Offer__c              = offerId,
        Amount__c             = amount,
        Conditions_Changed__c = conditions,
        Response_Deadline__c  = deadline,
        Status__c             = 'Pending',
        Proposed_By__c        = 'Seller',  // ← Seller counter verir
        Round_Number__c       = nextRound  // ← dinamik round
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