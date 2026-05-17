trigger BuyerTrigger on Buyer__c (before insert, before update, after insert, after update) {
    
     if(Trigger.isBefore) {

        if(Trigger.isInsert || Trigger.isUpdate) {
            BuyerTriggerHandler.beforeSave(Trigger.new);
        }
    }

    if(Trigger.isAfter) {

        if(Trigger.isInsert) {
            BuyerTriggerHandler.afterInsert(Trigger.new);
        }

        if(Trigger.isUpdate) {
            BuyerTriggerHandler.afterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}