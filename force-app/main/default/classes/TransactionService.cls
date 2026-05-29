public with sharing class TransactionService {

    public static final List<String> STAGES = new List<String>{
        'Pipeline',
        'Under Contract',
        'Inspection',
        'Appraisal',
        'Closing',
        'Closed'
    };

    @AuraEnabled(cacheable=true)
    public static List<Transaction__c> getPipeline() {
        return [
            SELECT  Id,
                    Status__c,
                    Property__c,
                    Buyer__c,
                    Property__r.Address__c,
                    Buyer__r.Name,
                    Offer__r.Offer_Amount__c,
                    Actual_Closing_Date__c,
                    Est_Closing_Date__c,
                    Sale_Price__c,
                    CreatedDate
            FROM Transaction__c
            ORDER BY CreatedDate DESC
        ];
    }

    @AuraEnabled
    public static void advanceStage(Id transactionId, String newStatus) {
        if (transactionId == null || String.isBlank(newStatus)) {
            throw new AuraHandledException('Missing parameters.');
        }
        if (!STAGES.contains(newStatus)) {
            throw new AuraHandledException('Invalid stage: ' + newStatus);
        }
        Transaction__c t = [
            SELECT Id, Status__c
            FROM Transaction__c
            WHERE Id = :transactionId
            LIMIT 1
        ];
        Integer currentIndex = STAGES.indexOf(t.Status__c);
        Integer newIndex     = STAGES.indexOf(newStatus);
        if (newIndex != currentIndex + 1) {
            throw new AuraHandledException(
                'Stage transition error: "' + t.Status__c + '" → "' + newStatus + '" is not valid.'
            );
        }
        t.Status__c = newStatus;
        update t;
    }

    // counterAmounts: Offer Id → Counter Offer qiyməti (boş ola bilər)
// counterAmounts: Offer Id → Counter Offer qiyməti (boş ola bilər)
public static void createTransaction(
    Set<Id> offerIds,
    Map<Id, Decimal> counterAmounts
) {
    if (offerIds == null || offerIds.isEmpty()) return;
    if (counterAmounts == null) counterAmounts = new Map<Id, Decimal>();

    // Duplikat yoxlaması
    Set<Id> existingOffers = new Set<Id>();
    for (Transaction__c t : [
        SELECT Offer__c
        FROM Transaction__c
        WHERE Offer__c IN :offerIds
    ]) {
        existingOffers.add(t.Offer__c);
    }

    List<Transaction__c> toInsert = new List<Transaction__c>();

    for (Offer__c o : [
        SELECT Id, Property__c, Buyer__c, Offer_Amount__c
        FROM Offer__c
        WHERE Id IN :offerIds
    ]) {
        if (existingOffers.contains(o.Id)) continue;

        // Counter offer varsa onun qiyməti, yoxdursa offer qiyməti
        Decimal finalPrice = counterAmounts.containsKey(o.Id)
            ? counterAmounts.get(o.Id)   // 350,000 ✓
            : o.Offer_Amount__c;         // 250,000 ✓

        toInsert.add(new Transaction__c(
            Offer__c      = o.Id,
            Property__c   = o.Property__c,
            Buyer__c      = o.Buyer__c,
            Status__c     = 'Pipeline',
            Sale_Price__c = finalPrice
        ));
    }

    if (!toInsert.isEmpty()) insert toInsert;
}
    @AuraEnabled(cacheable=true)
    public static Decimal getTotalPipelineValue() {
        AggregateResult ar = [
            SELECT SUM(Sale_Price__c) total
            FROM Transaction__c
            WHERE Status__c != 'Closed'
        ];
        Decimal val = (Decimal) ar.get('total');
        return val != null ? val : 0;
    }

    @AuraEnabled(cacheable=true)
    public static Decimal getTotalCommission() {
        List<Transaction__c> tx = [
            SELECT Sale_Price__c
            FROM Transaction__c
            WHERE Status__c != 'Closed'
        ];
        Decimal total = 0;
        for (Transaction__c t : tx) {
            if (t.Sale_Price__c != null) total += t.Sale_Price__c * 0.06;
        }
        return total;
    }
}