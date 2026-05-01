public with sharing class PropertyMatchBatchJob implements Database.Batchable<sObject> {
    
    public Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator([SELECT Id FROM Buyer__c WHERE Status__c = 'Active']);
    }

    public void execute(Database.BatchableContext BC, List<Buyer__c> scope) {
        for(Buyer__c b : scope) {
            try {
                PropertyMatchingService.matchBuyerToProperties(b.Id);
            } catch(Exception e) {
                System.debug('Xəta yarandı(ID: ' + b.Id + '): ' + e.getMessage());
            }
        }
    }

    public void finish(Database.BatchableContext BC) {
        System.debug('Property Matching Batch Prosesi Tamamlandı.');
    }
}