public with sharing class PropertyMatchingService {

    // =========================
    // SCORE DTO
    // =========================
    public class ScoreDTO {
        public Double total;
        public Double budgetScore;
        public Double locationScore;
        public Double typeScore;
        public Double roomScore;
        public Double areaScore;
        public Double featureScore;
    }

    // =========================
    // FLOW ENTRY
    // =========================
    @InvocableMethod
    public static void matchBuyerToPropertiesFlow(List<Id> buyerIds) {
        if (buyerIds == null || buyerIds.isEmpty()) return;
        matchBuyerToProperties(new Set<Id>(buyerIds));
    }

    @AuraEnabled
    public static void matchBuyerToProperties(Id buyerId) {
        if (buyerId == null) return;
        matchBuyerToProperties(new Set<Id>{ buyerId });
    }

    // =========================
    // MAIN ENGINE
    // =========================
    public static void matchBuyerToProperties(Set<Id> buyerIds) {

        if (buyerIds == null || buyerIds.isEmpty()) return;

        Map<Id, Buyer_Preference__c> prefs = new Map<Id, Buyer_Preference__c>();

        for (Buyer_Preference__c p : [
            SELECT Min_Budget__c, Max_Budget__c, Preferred_City__c,
                   Property_Type__c, Min_Bedrooms__c,
                   Neighborhoods__c, Min_Area__c,
                   Must_Have_Features__c, Buyer__c,
                   Alternative_Types__c, School_Preference__c
            FROM Buyer_Preference__c
            WHERE Buyer__c IN :buyerIds
        ]) {
            prefs.put(p.Buyer__c, p);
        }

        List<Property__c> properties = [
            SELECT Id, Asking_Price__c, City__c,
                   PropertyType__c, Bedrooms__c,
                   Neighborhood__c, Area__c,
                   Features__c, School_District__c
            FROM Property__c
            WHERE Status__c = 'Available'
        ];

        // =========================
        // EXISTING MATCHES (FOR UPDATE)
        // =========================
        Map<String, Property_Match__c> existingMap = new Map<String, Property_Match__c>();

        for (Property_Match__c m : [
            SELECT Id, Buyer__c, Property__c
            FROM Property_Match__c
            WHERE Buyer__c IN :buyerIds
        ]) {
            existingMap.put(m.Buyer__c + '-' + m.Property__c, m);
        }

        List<Property_Match__c> toInsert = new List<Property_Match__c>();
        List<Property_Match__c> toUpdate = new List<Property_Match__c>();

        // =========================
        // MAIN LOOP
        // =========================
        for (Id buyerId : buyerIds) {

            Buyer_Preference__c pref = prefs.get(buyerId);
            if (pref == null) continue;

            for (Property__c prop : properties) {

                String key = buyerId + '-' + prop.Id;

                ScoreDTO score = calculateMatchScore(pref, prop);

                // =========================
                // UPDATE EXISTING
                // =========================
                if (existingMap.containsKey(key)) {

                    Property_Match__c existing = existingMap.get(key);

                    existing.Match_Score__c = score.total;
                    existing.Budget_Score__c = score.budgetScore;
                    existing.Location_Score__c = score.locationScore;
                    existing.Type_Score__c = score.typeScore;
                    existing.Rooms_Score__c = score.roomScore;
                    existing.Area_Score__c = score.areaScore;
                    existing.Features_Score__c = score.featureScore;

                    toUpdate.add(existing);

                }
                // =========================
                // INSERT NEW
                // =========================
                else if (score.total >= 60) {

                    toInsert.add(new Property_Match__c(
                        Buyer__c = buyerId,
                        Property__c = prop.Id,

                        Match_Score__c = score.total,

                        Budget_Score__c = score.budgetScore,
                        Location_Score__c = score.locationScore,
                        Type_Score__c = score.typeScore,
                        Rooms_Score__c = score.roomScore,
                        Area_Score__c = score.areaScore,
                        Features_Score__c = score.featureScore,

                        Status__c = 'New'
                    ));
                }
            }
        }

        if (!toInsert.isEmpty()) insert toInsert;
        if (!toUpdate.isEmpty()) update toUpdate;
    }

    // =========================
    // SCORING ENGINE
    // =========================
    public static ScoreDTO calculateMatchScore(
        Buyer_Preference__c pref,
        Property__c prop
    ) {

        ScoreDTO dto = new ScoreDTO();

        // =========================
        // BUDGET
        // =========================
        Double budgetScore = 0;

        if (pref.Max_Budget__c != null && prop.Asking_Price__c != null) {

            if (prop.Asking_Price__c <= pref.Max_Budget__c) {
                budgetScore = 100;
            }
            else if (prop.Asking_Price__c <= pref.Max_Budget__c * 1.15) {
                budgetScore =
                    (1 - (
                        (prop.Asking_Price__c - pref.Max_Budget__c) /
                        (pref.Max_Budget__c * 0.15)
                    )) * 100;
            }
        }

        dto.budgetScore = budgetScore;
        dto.total = budgetScore * 0.25;

        // =========================
        // LOCATION
        // =========================
        Double locationScore = 0;

        if (prop.City__c != null && pref.Preferred_City__c != null) {

            if (prop.Neighborhood__c == pref.Neighborhoods__c) {
                locationScore = 100;
            }
            else if (prop.City__c == pref.Preferred_City__c) {
                locationScore = 70;
            }

            if (pref.School_Preference__c != null &&
                prop.School_District__c != null &&
                pref.School_Preference__c.contains(prop.School_District__c)) {

                locationScore = Math.max(locationScore, 90);
            }
        }

        dto.locationScore = locationScore;
        dto.total += locationScore * 0.25;

        // =========================
        // TYPE
        // =========================
        Double typeScore = 0;

        if (pref.Property_Type__c != null && prop.PropertyType__c != null) {

            Boolean mainMatch =
                pref.Property_Type__c.contains(prop.PropertyType__c);

            Boolean altMatch =
                pref.Alternative_Types__c != null &&
                pref.Alternative_Types__c.contains(prop.PropertyType__c);

            if (mainMatch) typeScore = 100;
            else if (altMatch) typeScore = 60;
        }

        dto.typeScore = typeScore;
        dto.total += typeScore * 0.15;

        // =========================
        // ROOMS (FIXED)
        // =========================
        Double roomScore = 0;

        if (pref.Min_Bedrooms__c != null && prop.Bedrooms__c != null) {

            Decimal diff = pref.Min_Bedrooms__c - prop.Bedrooms__c;

            if (diff <= 0) {
                roomScore = 100;
            } else {
                roomScore = Math.max(0, 100 - (diff * 20));
            }
        }

        dto.roomScore = roomScore;
        dto.total += roomScore * 0.15;

        // =========================
        // AREA (FIXED)
        // =========================
        Double areaScore = 0;

        if (pref.Min_Area__c != null &&
            prop.Area__c != null &&
            pref.Min_Area__c > 0) {

            areaScore = (prop.Area__c / pref.Min_Area__c) * 100;

            if (areaScore > 100) areaScore = 100;
        }

        dto.areaScore = areaScore;
        dto.total += areaScore * 0.10;

        // =========================
        // FEATURES
        // =========================
        Double featureScore = 0;

        Boolean hasFeatures =
            pref.Must_Have_Features__c != null &&
            pref.Must_Have_Features__c.trim() != '';

        if (hasFeatures && prop.Features__c != null) {

            List<String> features = pref.Must_Have_Features__c.split(';');
            Integer match = 0;

            for (String f : features) {
                if (prop.Features__c.contains(f)) {
                    match++;
                }
            }

            if (!features.isEmpty()) {
                featureScore =
                    (Double.valueOf(match) / features.size()) * 100;
            }
        }

        dto.featureScore = featureScore;
        dto.total += featureScore * 0.10;

        // =========================
        // GAP 2 - FEATURE CAP RULE
        // =========================
        if (hasFeatures && featureScore < 100) {
            dto.total = Math.min(dto.total, 50);
        }

        return dto;
    }

    // =========================
    // PROPERTY → BUYER FLOW
    // =========================
    public static void matchPropertyToBuyers(Set<Id> propertyIds) {

        if (propertyIds == null || propertyIds.isEmpty()) return;

        List<Property__c> properties = [
            SELECT Id, Asking_Price__c, City__c,
                   PropertyType__c, Bedrooms__c,
                   Neighborhood__c, Area__c,
                   Features__c, School_District__c
            FROM Property__c
            WHERE Id IN :propertyIds
        ];

        Map<Id, Buyer_Preference__c> prefs = new Map<Id, Buyer_Preference__c>();

        for (Buyer_Preference__c p : [
            SELECT Buyer__c, Min_Budget__c, Max_Budget__c,
                   Preferred_City__c, Property_Type__c,
                   Min_Bedrooms__c, Neighborhoods__c,
                   Min_Area__c, Must_Have_Features__c,
                   Alternative_Types__c, School_Preference__c
            FROM Buyer_Preference__c
            WHERE Buyer__c IN (
                SELECT Id FROM Buyer__c WHERE Status__c = 'Active'
            )
        ]) {
            prefs.put(p.Buyer__c, p);
        }

        List<Property_Match__c> toInsert = new List<Property_Match__c>();

        for (Id buyerId : prefs.keySet()) {

            Buyer_Preference__c pref = prefs.get(buyerId);
            if (pref == null) continue;

            for (Property__c prop : properties) {

                ScoreDTO score = calculateMatchScore(pref, prop);

                if (score.total >= 60) {

                    toInsert.add(new Property_Match__c(
                        Buyer__c = buyerId,
                        Property__c = prop.Id,
                        Match_Score__c = score.total,
                        Status__c = 'New'
                    ));
                }
            }
        }

        if (!toInsert.isEmpty()) insert toInsert;
    }
}