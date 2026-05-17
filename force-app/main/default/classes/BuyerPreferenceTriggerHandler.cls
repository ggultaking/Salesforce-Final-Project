public class BuyerPreferenceTriggerHandler {

    public static void refreshMatches(Set<Id> buyerIds) {

        if(buyerIds == null || buyerIds.isEmpty()) return;

       PropertyMatchingService.matchBuyerToProperties(buyerIds);
    }
}