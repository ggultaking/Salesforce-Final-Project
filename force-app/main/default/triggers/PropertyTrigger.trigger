trigger PropertyTrigger on Property__c (before insert, after insert, after update) {

    // if (Trigger.isBefore && Trigger.isInsert) {
    //     PropertyTriggerHandler.beforeInsert(Trigger.new);
    // }

    if (Trigger.isAfter && Trigger.isInsert) {
        PropertyTriggerHandler.afterInsert(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        PropertyTriggerHandler.afterUpdate(Trigger.new, Trigger.oldMap);
    }
}