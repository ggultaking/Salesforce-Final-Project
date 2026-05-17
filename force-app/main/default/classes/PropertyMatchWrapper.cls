public class PropertyMatchWrapper {

    @AuraEnabled public Id propertyId;
    @AuraEnabled public Id propertyMatchId;

    @AuraEnabled public String address;
    @AuraEnabled public Decimal price;

    @AuraEnabled public Decimal beds;
    @AuraEnabled public Decimal baths;
    @AuraEnabled public Decimal area;
    @AuraEnabled public String city;

    @AuraEnabled public Decimal matchScore;
    @AuraEnabled public String interestLevel;

    @AuraEnabled public Integer showingCount;
    @AuraEnabled public Integer daysOnMarket;

    @AuraEnabled public MatchBreakdown breakdown;
}