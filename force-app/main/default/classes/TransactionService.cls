public with sharing class TransactionService {

    // =========================
    // STAGES
    // =========================
    public static final List<String> STAGES = new List<String>{
        'Pipeline',
        'Under Contract',
        'Inspection',
        'Appraisal',
        'Closing',
        'Closed'
    };

    // =========================
    // GET PIPELINE (FIXED)
    // =========================
    @AuraEnabled(cacheable=true)
    public static List<Transaction__c> getPipeline() {

        return [
            SELECT Id,
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

    // =========================
    // ADVANCE STAGE
    // =========================
    @AuraEnabled
    public static void advanceStage(Id transactionId, String newStatus) {

        if (transactionId == null || String.isBlank(newStatus)) {
            throw new AuraHandledException('Missing parameters');
        }

        if (!STAGES.contains(newStatus)) {
            throw new AuraHandledException('Invalid stage');
        }

        Transaction__c t = [
            SELECT Id, Status__c
            FROM Transaction__c
            WHERE Id = :transactionId
            LIMIT 1
        ];

        Integer currentIndex = STAGES.indexOf(t.Status__c);
        Integer newIndex = STAGES.indexOf(newStatus);

        if (newIndex != currentIndex + 1) {
            throw new AuraHandledException('Invalid stage transition');
        }

        t.Status__c = newStatus;
        update t;
    }

    // =========================
    // CREATE FROM OFFER
    // =========================
    public static void createTransaction(Set<Id> offerIds) {

        if (offerIds == null || offerIds.isEmpty()) return;

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
            SELECT Id, Property__c, Buyer__c
            FROM Offer__c
            WHERE Id IN :offerIds
        ]) {

            if (existingOffers.contains(o.Id)) continue;

            toInsert.add(new Transaction__c(
                Offer__c = o.Id,
                Property__c = o.Property__c,
                Buyer__c = o.Buyer__c,
                Status__c = 'Pipeline'
            ));
        }

        if (!toInsert.isEmpty()) {
            insert toInsert;
        }
    }

    // =========================
    // TOTAL PIPELINE VALUE
    // =========================
    @AuraEnabled(cacheable=true)
    public static Decimal getTotalPipelineValue() {

        AggregateResult ar = [
            SELECT SUM(Sale_Price__c) total
            FROM Transaction__c
            WHERE Status__c != 'Closed'
        ];

        return (Decimal) ar.get('total');
    }

    // =========================
    // COMMISSION (FIXED LOGIC)
    // =========================
    @AuraEnabled(cacheable=true)
    public static Decimal getTotalCommission() {

        List<Transaction__c> tx = [
            SELECT Sale_Price__c
            FROM Transaction__c
            WHERE Status__c != 'Closed'
        ];

        Decimal total = 0;

        for (Transaction__c t : tx) {

            // FIXED: assume 3% commission (since no field exists)
            if (t.Sale_Price__c != null) {
                total += t.Sale_Price__c * 0.03;
            }
        }

        return total;
    }
}