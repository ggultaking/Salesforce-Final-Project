trigger BuyerPreferenceTrigger on Buyer_Preference__c (after insert, after update) {

    if(Trigger.isAfter) {

        Set<Id> buyerIds = new Set<Id>();

        for(Buyer_Preference__c bp : Trigger.new) {
            if(bp.Buyer__c != null) {
                buyerIds.add(bp.Buyer__c);
            }
        }

        if(!buyerIds.isEmpty()) {
            BuyerPreferenceTriggerHandler.refreshMatches(buyerIds);
        }
    }
}