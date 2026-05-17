public with sharing class PropertyMatchingService {

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

    // existing matches (1 time)
    Set<String> existingKeys = new Set<String>();
    for (Property_Match__c m : [
        SELECT Buyer__c, Property__c
        FROM Property_Match__c
        WHERE Buyer__c IN :buyerIds
    ]) {
        existingKeys.add(m.Buyer__c + '-' + m.Property__c);
    }

    List<Property_Match__c> toInsert = new List<Property_Match__c>();

    // =========================
    // REVERSED LOOP (OPTIMIZATION)
    // =========================
   for (Id buyerId : buyerIds) {

    Buyer_Preference__c pref = prefs.get(buyerId);
    if (pref == null) continue;

    for (Property__c prop : properties) {

        String key = buyerId + '-' + prop.Id;
        if (existingKeys.contains(key)) continue;

        Double score = calculateMatchScore(pref, prop);

        if (score >= 60) {

            toInsert.add(new Property_Match__c(
                Buyer__c = buyerId,
                Property__c = prop.Id,
                Match_Score__c = score,
                Status__c = 'New'
            ));
        }
    }
}
    if (!toInsert.isEmpty()) {
        upsert toInsert;
    }
}
public static void matchPropertyToBuyers(Set<Id> propertyIds) {

    if (propertyIds == null || propertyIds.isEmpty()) return;

    // 1. sadece ilgili property'leri çek
    List<Property__c> properties = [
        SELECT Id, Asking_Price__c, City__c,
               PropertyType__c, Bedrooms__c,
               Neighborhood__c, Area__c,
               Features__c, School_District__c
        FROM Property__c
        WHERE Id IN :propertyIds
    ];

    // 2. active buyer preference üzerinden buyer'ları bul
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

    Set<Id> buyerIds = prefs.keySet();

    // 3. artık gerçek matching
    matchBuyerPropertyPairs(buyerIds, properties, prefs);
}
private static void matchBuyerPropertyPairs(
    Set<Id> buyerIds,
    List<Property__c> properties,
    Map<Id, Buyer_Preference__c> prefs
) {

    List<Property_Match__c> toInsert = new List<Property_Match__c>();

    for (Id buyerId : buyerIds) {

        Buyer_Preference__c pref = prefs.get(buyerId);
        if (pref == null) continue;

        for (Property__c prop : properties) {

            Double score = calculateMatchScore(pref, prop);

            if (score >= 60) {
                toInsert.add(new Property_Match__c(
                    Buyer__c = buyerId,
                    Property__c = prop.Id,
                    Match_Score__c = score,
                    Status__c = 'New'
                ));
            }
        }
    }

    if (!toInsert.isEmpty()) {
        insert toInsert;
    }
}
    // =========================
    // SCORING ENGINE (FULL FIXED)
    // =========================
    public static Double calculateMatchScore(
        Buyer_Preference__c pref,
        Property__c prop
    ) {
        Double total = 0;

        // =========================
        // BUDGET (RESTORED + TOLERANCE)
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
            else {
                budgetScore = 0;
            }
        }

        total += budgetScore * 0.25;

        // =========================
        // LOCATION + SCHOOL BONUS (RESTORED)
        // =========================
        Double locationScore = 0;

        if (prop.City__c != null && pref.Preferred_City__c != null) {

            if (prop.Neighborhood__c == pref.Neighborhoods__c) {
                locationScore = 100;
            }
            else if (prop.City__c == pref.Preferred_City__c) {
                locationScore = 70;
            }

            // SCHOOL BOOST
            if (pref.School_Preference__c != null &&
                prop.School_District__c != null &&
                pref.School_Preference__c.contains(prop.School_District__c)) {

                if (locationScore == 70) locationScore = 90;
                else if (locationScore == 0) locationScore = 60;
            }
        }

        total += locationScore * 0.25;

        // =========================
        // TYPE + ALTERNATIVE TYPES (RESTORED)
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

        total += typeScore * 0.15;

        // =========================
        // BEDROOMS
        // =========================
        Double roomScore = 0;

        if (pref.Min_Bedrooms__c != null && prop.Bedrooms__c != null) {
            roomScore =
                (prop.Bedrooms__c >= pref.Min_Bedrooms__c) ? 100 : 0;
        }

        total += roomScore * 0.15;

        // =========================
        // AREA
        // =========================
        Double areaScore = 0;

        if (pref.Min_Area__c != null && prop.Area__c != null) {
            areaScore =
                (prop.Area__c >= pref.Min_Area__c) ? 100 : 0;
        }

        total += areaScore * 0.10;

        // =========================
        // FEATURES (NULL SAFE FIX)
        // =========================
        Double featureScore = 0;

        if (pref.Must_Have_Features__c != null &&
            prop.Features__c != null) {

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

            total += featureScore * 0.10;
        }

        return total;
    }
}