trigger PropertyTrigger on Property__c (before insert, after insert, after update) {

    // if (Trigger.isBefore && Trigger.isInsert) {
    //     PropertyTriggerHandler.beforeInsert(Trigger.new);
    // }

    if (Trigger.isAfter && Trigger.isInsert) {
        PropertyTriggerHandler.afterInsert(Trigger.new);
        System.debug('🔥 PROPERTY TRIGGER FIRED');
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        PropertyTriggerHandler.afterUpdate(Trigger.new, Trigger.oldMap);
        System.debug('🔥 PROPERTY TRIGGER FIRED');
    }


    Set<Id> soldPropertyIds = new Set<Id>();

    for (Property__c p : Trigger.new) {
        Property__c oldP = Trigger.oldMap.get(p.Id);

        // STATUS SOLD'a geçiş anı
        if (p.Status__c == 'Sold' && oldP.Status__c != 'Sold') {
            soldPropertyIds.add(p.Id);
        }
    }

    if (!soldPropertyIds.isEmpty()) {
        PropertyMatchingService.removeMatchesForSoldProperties(soldPropertyIds);
    }
}
