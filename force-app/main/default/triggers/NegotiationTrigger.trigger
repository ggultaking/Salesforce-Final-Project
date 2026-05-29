trigger NegotiationTrigger on Negotiation__c (after update) {
    if (Trigger.isAfter && Trigger.isUpdate) {
        NegotiationTriggerHandler.afterUpdate(Trigger.new, Trigger.oldMap);
    }
}