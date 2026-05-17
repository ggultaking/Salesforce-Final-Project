public class TransactionTriggerHandler {

    // =========================
    // BEFORE UPDATE
    // =========================
  public static void beforeUpdate(
    List<Transaction__c> newRecords,
    Map<Id, Transaction__c> oldMap
) {

    for (Transaction__c t : newRecords) {

        Transaction__c oldT = oldMap.get(t.Id);
        if (oldT == null) continue;

        // =====================================
        // 1. FIELD RESET LOGIC
        // =====================================
  
        // =====================================
        // 2. STATUS VALIDATION
        // =====================================
       if (oldT.Status__c != t.Status__c) {

    TransactionStatusValidator.validate(
        oldT.Status__c,
        t.Status__c
    );
}
    }
}

    // =========================
    // AFTER UPDATE
    // =========================
    public static void afterUpdate(
        List<Transaction__c> newRecords,
        Map<Id, Transaction__c> oldMap
    ) {

        TransactionBusinessService.handleAfterUpdate(
            newRecords,
            oldMap
        );
    }
}