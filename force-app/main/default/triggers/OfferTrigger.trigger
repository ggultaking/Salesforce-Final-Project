trigger OfferTrigger on Offer__c (before insert, before update, after update) {

    if (Trigger.isBefore && Trigger.isInsert) {
        OfferTriggerHandler.beforeInsert(Trigger.new);
    }

    // if (Trigger.isBefore && Trigger.isUpdate) {
    //     OfferTriggerHandler.beforeUpdate(Trigger.new);
    // }

    if (Trigger.isAfter && Trigger.isUpdate) {
        OfferTriggerHandler.afterUpdate(Trigger.new, Trigger.oldMap);
    }
}