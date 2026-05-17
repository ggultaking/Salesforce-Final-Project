@isTest
public class TestDataFactory {

    public static Property__c createProperty() {
        Property__c p = new Property__c(
         
            Asking_Price__c = 100000,
            City__c = 'Baku',
            Status__c = 'Available',
            PropertyType__c = 'Apartment',
            Bedrooms__c = 2,
            Area__c = 120
        );
        insert p;
        return p;
    }

    public static Buyer__c createBuyer() {
        Buyer__c b = new Buyer__c(
           
            Email__c = 'test@test.com',
            Status__c = 'Active'
        );
        insert b;
        return b;
    }

    public static Buyer_Preference__c createPreference(Id buyerId) {
        Buyer_Preference__c p = new Buyer_Preference__c(
            Buyer__c = buyerId,
            Max_Budget__c = 150000,
            Preferred_City__c = 'Baku',
            Property_Type__c = 'Apartment',
            Min_Bedrooms__c = 2,
            Min_Area__c = 100
        );
        insert p;
        return p;
    }

    public static Offer__c createOffer(Id buyerId, Id propertyId) {
        Offer__c o = new Offer__c(
            Buyer__c = buyerId,
            Property__c = propertyId,
            Offer_Amount__c = 120000,
            Status__c = 'Active'
        );
        insert o;
        return o;
    }

    public static Transaction__c createTransaction(Id offerId, Id propertyId, Id buyerId) {
        Transaction__c t = new Transaction__c(
            Offer__c = offerId,
            Property__c = propertyId,
            Buyer__c = buyerId,
            Status__c = 'Pending'
        );
        insert t;
        return t;
    }
}