public with sharing class PropertyMatchingService {
    @InvocableMethod()
    public static void matchBuyerToPropertiesFlow(List<Id> buyerIds) {
        for(Id bId : buyerIds) {
            matchBuyerToProperties(bId); // Mevcut metodunu çağırıyor
        }
    }
    @AuraEnabled
    public static void matchBuyerToProperties(Id buyerId) {
       Buyer_Preference__c pref = [SELECT Min_Budget__c, Max_Budget__c, Preferred_City__c, 
                                    Property_Type__c, Min_Bedrooms__c, Min_Bathrooms__c,Neighborhoods__c, 
                                    Min_Area__c, Must_Have_Features__c, Buyer__c,Alternative_Types__c,School_Preference__c 
                                    FROM Buyer_Preference__c WHERE Buyer__c = :buyerId LIMIT 1];
        List<Property_Match__c> oldMatches = [SELECT Id FROM Property_Match__c WHERE Buyer__c = :buyerId];
        if(!oldMatches.isEmpty()) {
            delete oldMatches; 
        }
        List<Property__c> properties = [SELECT Id, Name, Asking_Price__c, City__c, PropertyType__c, 
                                        Bedrooms__c, Neighborhood__c, Bathrooms__c, Area__c, Features__c,School_District__c 
                                        FROM Property__c WHERE Status__c = 'Available'];
        
        List<Property_Match__c> matchesToCreate = new List<Property_Match__c>();

        for(Property__c prop : properties) {
            Double totalScore = 0;
            Boolean mandatoryMissing = false;
      
            Double budgetScore = (prop.Asking_Price__c <= pref.Max_Budget__c) ? 100 : 
                                 (prop.Asking_Price__c <= pref.Max_Budget__c * 1.15) ? (1 - (prop.Asking_Price__c - pref.Max_Budget__c) / (pref.Max_Budget__c * 0.15)) * 100 : 0;
            totalScore += budgetScore * 0.25;

    
        
            Double locationScore = (prop.Neighborhood__c == pref.Neighborhoods__c) ? 100 : 
                       (prop.City__c == pref.Preferred_City__c) ? 70 : 0;

             Boolean schoolMatch = false;

if(pref.School_Preference__c != null && prop.School_District__c != null) {
    schoolMatch = pref.School_Preference__c.contains(prop.School_District__c);
}

if(locationScore == 70 && schoolMatch) {
    locationScore = 90;
} else if(locationScore == 0 && schoolMatch) {
    locationScore = 60;
}          
            totalScore += locationScore * 0.25;
  
           Double typeScore = (pref.Property_Type__c != null && pref.Property_Type__c.contains(prop.PropertyType__c)) ? 100 : 
                   (pref.Alternative_Types__c != null && pref.Alternative_Types__c.contains(prop.PropertyType__c)) ? 60 : 0;

            totalScore += typeScore * 0.15;

    
            Double roomScore = (prop.Bedrooms__c >= pref.Min_Bedrooms__c) ? 100 : Math.max(0, 100 - (pref.Min_Bedrooms__c - prop.Bedrooms__c) * 20);
            totalScore += roomScore * 0.15;

            Double areaScore = (prop.Area__c >= pref.Min_Area__c) ? 100 : (prop.Area__c / pref.Min_Area__c) * 100;
            totalScore += areaScore * 0.10;

            Double featureScore = 0; 
     if (pref.Must_Have_Features__c != null) {
                List<String> requiredFeatures = pref.Must_Have_Features__c.split(';');
                Integer matchCount = 0;
                for (String f : requiredFeatures) {
                    if (prop.Features__c != null && prop.Features__c.contains(f)) {
                        matchCount++;
                    } else {
                        mandatoryMissing = true; 
                    }
                }
                featureScore = (Double.valueOf(matchCount) / requiredFeatures.size()) * 100;
                totalScore += featureScore * 0.10;
            }
            totalScore = (mandatoryMissing) ? Math.min(totalScore, 50) : totalScore;
          
            if(totalScore >= 60) {
                matchesToCreate.add(new Property_Match__c(
                    Buyer__c = pref.Buyer__c,
                    Property__c = prop.Id,
                    Match_Score__c = totalScore,
                    Budget_Score__c = budgetScore,
                    Location_Score__c = locationScore,
                    Type_Score__c = typeScore, 
                    Status__c = 'New'
                ));
            }
        }
        
        if(!matchesToCreate.isEmpty()){
            upsert matchesToCreate; 
            
       
            for(Property_Match__c m : matchesToCreate) {
                if(m.Match_Score__c >= 80) {
                    System.debug( m.Match_Score__c);
                }
            }
        }
    }
}