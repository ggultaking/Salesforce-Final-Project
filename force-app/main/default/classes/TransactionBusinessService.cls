public class TransactionBusinessService {

    public static void handleAfterUpdate(
        List<Transaction__c> newRecords,
        Map<Id, Transaction__c> oldMap
    ) {

        Set<Id> closedIds = new Set<Id>();

        for (Transaction__c t : newRecords) {

            Transaction__c oldT = oldMap.get(t.Id);
            if (oldT == null) continue;

            // =========================
            // STATUS → CLOSED
            // =========================
            if (t.Status__c == 'Closed'
                && oldT.Status__c != 'Closed') {

                closedIds.add(t.Id);
TransactionBusinessService.updatePropertyToSold(t);
            }
        }

        // =========================
        // COMMISSION CREATION
        // =========================
        if (!closedIds.isEmpty()) {

           CommissionService.calculateCommissions(closedIds);
        }
    }
    private static void updatePropertyToSold(Transaction__c t) {

    if (t.Property__c == null) return;

    Property__c p = [
        SELECT Id, Status__c
        FROM Property__c
        WHERE Id = :t.Property__c
        LIMIT 1
    ];

    p.Status__c = 'Sold';
    update p;
}
}