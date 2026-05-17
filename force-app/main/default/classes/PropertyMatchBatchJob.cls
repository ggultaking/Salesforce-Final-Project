public with sharing class PropertyMatchBatchJob
implements Database.Batchable<sObject> {

    /*
    =========================================
    START
    =========================================
    */

    public Database.QueryLocator start(
        Database.BatchableContext BC
    ) {

        return Database.getQueryLocator(

            [
                SELECT Id
                FROM Buyer__c
                WHERE Status__c = 'Active'
            ]
        );
    }

    /*
    =========================================
    EXECUTE
    =========================================
    */

    public void execute(
        Database.BatchableContext BC,
        List<Buyer__c> scope
    ) {

        Set<Id> buyerIds = new Set<Id>();

        for(Buyer__c b : scope) {

            if(b.Id != null) {
                buyerIds.add(b.Id);
            }
        }

        if(buyerIds.isEmpty()) {
            return;
        }

        try {

            PropertyMatchingService.matchBuyerToProperties(buyerIds);

        } catch(Exception e) {

            System.debug(
                'Property Matching Batch Error: '
                + e.getMessage()
            );
        }
    }

    /*
    =========================================
    FINISH
    =========================================
    */

    public void finish(
        Database.BatchableContext BC
    ) {

        System.debug(
            'Property Matching Batch Process Completed.'
        );
    }
}