public class PropertyTriggerHandler {

    public static void afterInsert(List<Property__c> newProperties){

        Set<Id> propertyIds = new Set<Id>();

        for(Property__c prop : newProperties){
            propertyIds.add(prop.Id);
        }

        if(propertyIds.isEmpty()) return;

       PropertyMatchingService.matchPropertyToBuyers(propertyIds);
    }

    public static void afterUpdate(
        List<Property__c> newProperties,
        Map<Id, Property__c> oldMap
    ){

        Set<Id> reMatchIds = new Set<Id>();
        Set<Id> soldIds = new Set<Id>();

        for(Property__c newProp : newProperties){

            Property__c oldProp = oldMap.get(newProp.Id);
            if(oldProp == null) continue;

            Boolean priceChanged =
                newProp.Asking_Price__c != oldProp.Asking_Price__c;

            Boolean statusChanged =
                newProp.Status__c != oldProp.Status__c;

            // =========================
            // RE-MATCH CONDITION
            // =========================
            if(priceChanged || statusChanged){
                reMatchIds.add(newProp.Id);
            }

            // =========================
            // SOLD DETECTION (NEW ADDITION)
            // =========================
            if(newProp.Status__c == 'Sold'
                && oldProp.Status__c != 'Sold'){
                soldIds.add(newProp.Id);
            }
        }

        // =========================
        // RE-MATCH CALL
        // =========================
        if(!reMatchIds.isEmpty()){
            PropertyMatchingService.matchPropertyToBuyers(reMatchIds);
        }

        // =========================
        // SOLD CLEANUP (NEW ADDITION)
        // =========================
        if(!soldIds.isEmpty()){

          List<Property_Match__c> matchesToClose = [
    SELECT Id
    FROM Property_Match__c
    WHERE Property__c IN :soldIds
    AND Status__c != 'Closed'
];

for (Property_Match__c m : matchesToClose) {
    m.Status__c = 'Closed';
}

if (!matchesToClose.isEmpty()) {
    update matchesToClose;
}

List<Offer__c> offersToClose = [
    SELECT Id
    FROM Offer__c
    WHERE Property__c IN :soldIds
    AND Status__c != 'Closed'
];

for (Offer__c o : offersToClose) {
    o.Status__c = 'Closed';
}

if (!offersToClose.isEmpty()) {
    update offersToClose;
}
        }
    }
    
}