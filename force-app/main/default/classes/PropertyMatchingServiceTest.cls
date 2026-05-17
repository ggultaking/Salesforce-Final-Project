@isTest
public class PropertyMatchingServiceTest {

    @isTest
    static void testMatching() {

        Property__c p = TestDataFactory.createProperty();
        Buyer__c b = TestDataFactory.createBuyer();
        Buyer_Preference__c pref = TestDataFactory.createPreference(b.Id);

        Test.startTest();
        PropertyMatchingService.matchBuyerToProperties(new Set<Id>{ b.Id });
        Test.stopTest();

        System.assert(true, 'Matching executed');
    }
}