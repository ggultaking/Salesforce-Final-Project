public with sharing class PropertyMatchController {

    // =====================================================
    // GET TOP MATCHES (FULL REQUIREMENT VERSION)
    // =====================================================
    @AuraEnabled(cacheable=true)
    public static List<PropertyMatchWrapper> getTopMatches(
        Id buyerId,
        Decimal minPrice,
        Decimal maxPrice,
        List<String> propertyTypes,
        Decimal minScore,
        Boolean hotOnly
    ) {

        // =========================
        // SHOWING COUNT MAP
        // =========================
        Map<Id, Integer> showingMap = new Map<Id, Integer>();

        for (AggregateResult ar : [
            SELECT Property__c propertyId, COUNT(Id) cnt
            FROM Showing__c
            WHERE Buyer__c = :buyerId
            GROUP BY Property__c
        ]) {
            showingMap.put((Id)ar.get('propertyId'), (Integer)ar.get('cnt'));
        }

        // =========================
        // BASE QUERY
        // =========================
        List<Property_Match__c> matches = [
            SELECT Id,
                   Property__c,
                   Match_Score__c,

                   Area_Score__c,
                   Budget_Score__c,
                   Features_Score__c,
                   Location_Score__c,
                   Rooms_Score__c,
                   Type_Score__c,

                   Property__r.Address__c,
                   Property__r.Asking_Price__c,
                   Property__r.Bedrooms__c,
                   Property__r.Bathrooms__c,
                   Property__r.Area__c,
                   Property__r.City__c,
                   Property__r.PropertyType__c,
                   Property__r.List_Date__c
            FROM Property_Match__c
            WHERE Buyer__c = :buyerId
        ];

        List<PropertyMatchWrapper> result = new List<PropertyMatchWrapper>();

        for (Property_Match__c pm : matches) {

            Decimal price = pm.Property__r != null
                ? pm.Property__r.Asking_Price__c
                : 0;

            // =====================================================
            // FILTERS (BACKEND ENFORCED)
            // =====================================================

            if (minPrice != null && price < minPrice) continue;
            if (maxPrice != null && price > maxPrice) continue;

            if (propertyTypes != null && !propertyTypes.isEmpty()) {
                if (pm.Property__r == null ||
                    !propertyTypes.contains(pm.Property__r.PropertyType__c)) {
                    continue;
                }
            }

            Decimal score = pm.Match_Score__c != null
                ? pm.Match_Score__c * 100
                : 0;

            if (minScore != null && score < minScore) continue;

            if (hotOnly == true && score < 80) continue;

            // =====================================================
            // WRAPPER
            // =====================================================
            PropertyMatchWrapper w = new PropertyMatchWrapper();

            w.propertyId = pm.Property__c;
            w.propertyMatchId = pm.Id;

            // =========================
            // PROPERTY INFO
            // =========================
            w.address = pm.Property__r != null ? pm.Property__r.Address__c : null;
            w.price = price;

            w.beds = pm.Property__r != null ? pm.Property__r.Bedrooms__c : null;
            w.baths = pm.Property__r != null ? pm.Property__r.Bathrooms__c : null;
            w.area = pm.Property__r != null ? pm.Property__r.Area__c : null;
            w.city = pm.Property__r != null ? pm.Property__r.City__c : null;

            // =========================
            // DAYS ON MARKET (REAL REQUIREMENT FIX)
            // =========================
            if (pm.Property__r != null && pm.Property__r.List_Date__c != null) {
                w.daysOnMarket = Date.today()
                    .daysBetween(pm.Property__r.List_Date__c);
            } else {
                w.daysOnMarket = 0;
            }

            // =========================
            // SCORE
            // =========================
            w.matchScore = score;

            // =========================
            // INTEREST LEVEL (ENHANCED RULE)
            // =========================
            if (score >= 80) w.interestLevel = 'Hot';
            else if (score >= 60) w.interestLevel = 'Warm';
            else w.interestLevel = 'Cold';

            // =========================
            // SHOWING COUNT
            // =========================
            w.showingCount = showingMap.containsKey(pm.Property__c)
                ? showingMap.get(pm.Property__c)
                : 0;

            // =========================
            // BREAKDOWN
            // =========================
            MatchBreakdown b = new MatchBreakdown();

            b.areaScore = pm.Area_Score__c;
            b.budgetScore = pm.Budget_Score__c;
            b.featuresScore = pm.Features_Score__c;
            b.locationScore = pm.Location_Score__c;
            b.roomsScore = pm.Rooms_Score__c;
            b.typeScore = pm.Type_Score__c;

            w.breakdown = b;

            result.add(w);
        }

        // =========================
        // SORT (APEX SAFE)
        // =========================
        for (Integer i = 0; i < result.size(); i++) {
            for (Integer j = i + 1; j < result.size(); j++) {
                if (result[j].matchScore > result[i].matchScore) {
                    PropertyMatchWrapper temp = result[i];
                    result[i] = result[j];
                    result[j] = temp;
                }
            }
        }

        return result;
    }

    // =====================================================
    // NOT INTERESTED
    // =====================================================
    @AuraEnabled
    public static void markNotInterested(Id propertyMatchId) {

        Property_Match__c pm = [
            SELECT Id, Status__c
            FROM Property_Match__c
            WHERE Id = :propertyMatchId
            LIMIT 1
        ];

        pm.Status__c = 'Not Interested';
        update pm;
    }

    // =====================================================
    // SCHEDULE SHOWING
    // =====================================================
    @AuraEnabled
    public static Id scheduleShowing(
        Id propertyId,
        Id buyerId,
        Datetime showingDateTime,
        Integer durationMinutes
    ) {

        Showing__c s = new Showing__c();

        s.Property__c = propertyId;
        s.Buyer__c = buyerId;

        s.Showing_Date_Time__c = showingDateTime;
        s.Duration__c = durationMinutes;
        s.Status__c = 'Scheduled';

        insert s;
        return s.Id;
    }

    // =====================================================
    // SHOWING HISTORY
    // =====================================================
    @AuraEnabled(cacheable=true)
    public static List<Showing__c> getShowingHistory(Id propertyId, Id buyerId) {

        return [
            SELECT Id,
                   Showing_Date_Time__c,
                   Duration__c,
                   Status__c,
                   Rating__c,
                   Interest_Level__c,
                   Buyer_Feedback__c
            FROM Showing__c
            WHERE Property__c = :propertyId
            AND Buyer__c = :buyerId
            ORDER BY Showing_Date_Time__c DESC
        ];
    }
}