@isTest
public class TriggerTests {

    @isTest
    static void testPropertyTrigger() {

        Property__c p = new Property__c(
          
            Asking_Price__c = 100000,
            Status__c = 'Available'
        );

        insert p;

        p.Asking_Price__c = 120000;
        update p;
    }

    @isTest
    static void testBuyerTrigger() {

        Buyer__c b = new Buyer__c(
            
            Email__c = 'unique@test.com',
            Status__c = 'Active'
        );

        insert b;

        b.Status__c = 'Active';
        update b;
    }

    @isTest
    static void testOfferTrigger() {

        Property__c p = TestDataFactory.createProperty();
        Buyer__c b = TestDataFactory.createBuyer();

        Offer__c o = TestDataFactory.createOffer(b.Id, p.Id);

        o.Status__c = 'Accepted';
        update o;
    }

    @isTest
    static void testTransactionTrigger() {

        Property__c p = TestDataFactory.createProperty();
        Buyer__c b = TestDataFactory.createBuyer();
        Offer__c o = TestDataFactory.createOffer(b.Id, p.Id);

        Transaction__c t = TestDataFactory.createTransaction(o.Id, p.Id, b.Id);

        t.Status__c = 'Closed';
        update t;
    }
}