public class BuyerTriggerHandler {

    public static void beforeSave(List<Buyer__c> newBuyers) {

        Set<String> emails = new Set<String>();
        Map<String, Id> emailToId = new Map<String, Id>();

        for (Buyer__c b : newBuyers) {
            if (String.isNotBlank(b.Email__c)) {
                emails.add(b.Email__c.toLowerCase().trim());
            }
        }

        if (emails.isEmpty()) return;

        for (Buyer__c existing : [
            SELECT Id, Email__c
            FROM Buyer__c
            WHERE Email__c IN :emails
        ]) {
            if (existing.Email__c == null) continue;

            emailToId.put(existing.Email__c.toLowerCase().trim(), existing.Id);
        }

        for (Buyer__c b : newBuyers) {
            if (String.isNotBlank(b.Email__c)) {

                String email = b.Email__c.toLowerCase().trim();

                if (emailToId.containsKey(email)) {

                    // self-check fix
                    if (b.Id == null || emailToId.get(email) != b.Id) {
                        b.Email__c.addError('This email already exists.');
                    }
                }
            }
        }
    }

    public static void afterInsert(List<Buyer__c> newBuyers) {

        Set<Id> buyerIds = new Set<Id>();
        for (Buyer__c b : newBuyers) {
            buyerIds.add(b.Id);
        }

        if (buyerIds.isEmpty()) return;

        Set<Id> buyerIdsWithPref = new Set<Id>();

        for (Buyer__c b : [
            SELECT Id
            FROM Buyer__c
            WHERE Id IN :buyerIds
            AND Id IN (SELECT Buyer__c FROM Buyer_Preference__c)
        ]) {
            buyerIdsWithPref.add(b.Id);
        }

        if (!buyerIdsWithPref.isEmpty()) {
            PropertyMatchingService.matchBuyerToProperties(buyerIdsWithPref);
        }
    }

    public static void afterUpdate(
        List<Buyer__c> newBuyers,
        Map<Id, Buyer__c> oldMap
    ) {

        Set<Id> activeBuyerIds = new Set<Id>();

        for (Buyer__c newB : newBuyers) {

            Buyer__c oldB = oldMap.get(newB.Id);
            if (oldB == null) continue;

            if (newB.Status__c == 'Active' &&
                oldB.Status__c != 'Active') {

                activeBuyerIds.add(newB.Id);
            }
        }

        if (!activeBuyerIds.isEmpty()) {
            PropertyMatchingService.matchBuyerToProperties(activeBuyerIds);
        }
    }
}