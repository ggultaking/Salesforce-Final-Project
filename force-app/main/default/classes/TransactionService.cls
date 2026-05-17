public class TransactionService {

    public static void createTransaction(Set<Id> offerIds) {

        if (offerIds == null || offerIds.isEmpty()) return;

        // burada transaction record creation olur
        // örnek placeholder:
        Set<Id> existingOfferIds = new Set<Id>();

for (Transaction__c t : [
    SELECT Offer__c
    FROM Transaction__c
    WHERE Offer__c IN :offerIds
]) {
    existingOfferIds.add(t.Offer__c);
}
        List<Transaction__c> txs = new List<Transaction__c>();

        for (Offer__c o : [
            SELECT Id, Property__c, Buyer__c, Offer_Amount__c
            FROM Offer__c
            WHERE Id IN :offerIds
        ]) {
            if (existingOfferIds.contains(o.Id)) {
    continue;
}

            txs.add(new Transaction__c(
                Offer__c = o.Id,
                Property__c = o.Property__c,
                Buyer__c = o.Buyer__c
            ));
        }

        if (!txs.isEmpty()) {
            insert txs;
        }
    }
    public static void advanceStage(Id transactionId, String newStatus) {
    if (transactionId == null || String.isBlank(newStatus)) return;

    Transaction__c t = [
        SELECT Id, Status__c
        FROM Transaction__c
        WHERE Id = :transactionId
        LIMIT 1
    ];

    TransactionStatusValidator.validate(t.Status__c, newStatus);

    t.Status__c = newStatus;
    update t;
}
public static void closeTransaction(Id transactionId, Date closingDate, Decimal salePrice) {
    if (transactionId == null) return;

    Transaction__c t = [
        SELECT Id, Property__c
        FROM Transaction__c
        WHERE Id = :transactionId
        LIMIT 1
    ];

    t.Status__c = 'Closed';
    update t;
}
}