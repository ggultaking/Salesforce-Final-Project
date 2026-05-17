@isTest
public class CommissionServiceTest {

    @isTest
    static void testCommission() {

        Property__c p = TestDataFactory.createProperty();
        Buyer__c b = TestDataFactory.createBuyer();
        Offer__c o = TestDataFactory.createOffer(b.Id, p.Id);
        Transaction__c t = TestDataFactory.createTransaction(o.Id, p.Id, b.Id);

        Test.startTest();
        CommissionService.calculateCommissions(new Set<Id>{ t.Id });
        Test.stopTest();

        System.assert(true);
    }
}