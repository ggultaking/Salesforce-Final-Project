trigger TransactionTrigger on Transaction__c (
    
    before update,
    after update
) {

     if (Trigger.isBefore && Trigger.isUpdate) {
        TransactionTriggerHandler.beforeUpdate(
            Trigger.new,
            Trigger.oldMap
        );
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        TransactionTriggerHandler.afterUpdate(
            Trigger.new,
            Trigger.oldMap
        );
    }
}