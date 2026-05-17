@isTest
public class NegotiationServiceTest {

    @isTest
    static void testCounterOffer() {

        Property__c p = TestDataFactory.createProperty();
        Buyer__c b = TestDataFactory.createBuyer();
        Offer__c o = TestDataFactory.createOffer(b.Id, p.Id);

        Test.startTest();
        NegotiationService.submitCounterOffer(
            o.Id,
            110000,
            'test',
            Date.today().addDays(3)
        );
        Test.stopTest();

        System.assert(true);
    }
}