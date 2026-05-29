public with sharing class PropertyMatchController {

    // =====================================================
    // INNER CLASSES
    // =====================================================
    public class OfferSummaryWrapper {
        @AuraEnabled public Id      propertyMatchId;
        @AuraEnabled public Integer offerCount;
    }

    // =====================================================
    // GET TOP MATCHES
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
  // =========================
// SHOWING COUNT MAP — property bazında (bütün buyerlar)
// =========================
Map<Id, Integer> showingMap = new Map<Id, Integer>();
for (AggregateResult ar : [
    SELECT Property__c propertyId, COUNT(Id) cnt
    FROM Showing__c
    GROUP BY Property__c
]) {
    showingMap.put((Id) ar.get('propertyId'), (Integer) ar.get('cnt'));
}

// =========================
// BU BUYER-IN SHOWING MAP — buyer bazında
// =========================
Map<Id, Integer> buyerShowingMap = new Map<Id, Integer>();
for (AggregateResult ar : [
    SELECT Property__c propertyId, COUNT(Id) cnt
    FROM Showing__c
    WHERE Buyer__c = :buyerId
    GROUP BY Property__c
]) {
    buyerShowingMap.put((Id) ar.get('propertyId'), (Integer) ar.get('cnt'));
}

        // =========================
        // QUERY
        // =========================
        List<Property_Match__c> matches = [
            SELECT Id,
                   Property__c,
                   Match_Score__c,
                   Viewed_Count__c,
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
                   Property__r.Days_on_Market__c,
                   Status__c
            FROM Property_Match__c
            WHERE Buyer__c = :buyerId
            AND Status__c NOT IN ('Sold', 'Closed') 
        ];

        List<PropertyMatchWrapper> result = new List<PropertyMatchWrapper>();

        for (Property_Match__c pm : matches) {

            Decimal price =
                pm.Property__r != null
                ? pm.Property__r.Asking_Price__c
                : 0;

            // =========================
            // FILTERS
            // =========================
            if (minPrice != null && price < minPrice) continue;
            if (maxPrice != null && price > maxPrice) continue;

            if (propertyTypes != null && !propertyTypes.isEmpty()) {
                if (pm.Property__r == null ||
                    !propertyTypes.contains(pm.Property__r.PropertyType__c)) {
                    continue;
                }
            }

            Decimal score =
                pm.Match_Score__c != null
                ? pm.Match_Score__c.setScale(2)
                : 0;

            if (minScore != null && score < minScore) continue;
            if (hotOnly == true && score < 80)        continue;

            // =========================
            // WRAPPER
            // =========================
            PropertyMatchWrapper w = new PropertyMatchWrapper();

            w.photoUrl        = getPropertyPhotoUrl(pm.Property__c);
            w.propertyId      = pm.Property__c;
            w.propertyMatchId = pm.Id;
            w.status          = pm.Status__c;

    // viewedCount — property-nin ümumi görüntülənmə sayı (bütün buyerlar)
w.viewedCount =
    showingMap.containsKey(pm.Property__c)
    ? showingMap.get(pm.Property__c)
    : 0;

// showingCount — yalnız bu buyer-ın bu property-ni görmə sayı


            w.address =
                pm.Property__r != null
                ? pm.Property__r.Address__c
                : null;

            w.price = price;

            w.beds =
                pm.Property__r != null
                ? pm.Property__r.Bedrooms__c
                : null;

            w.baths =
                pm.Property__r != null
                ? pm.Property__r.Bathrooms__c
                : null;

            w.area =
                pm.Property__r != null
                ? pm.Property__r.Area__c
                : null;

            w.city =
                pm.Property__r != null
                ? pm.Property__r.City__c
                : null;

            w.daysOnMarket =
                (pm.Property__r != null && pm.Property__r.Days_on_Market__c != null)
                ? Integer.valueOf(pm.Property__r.Days_on_Market__c)
                : 0;

            w.matchScore = score;

            // =========================
            // INTEREST LEVEL
            // =========================
            if      (score >= 80) { w.interestLevel = 'Hot';  }
            else if (score >= 60) { w.interestLevel = 'Warm'; }
            else                  { w.interestLevel = 'Cold'; }

            // =========================
            // SHOWING COUNT
            // =========================
            w.showingCount =
                showingMap.containsKey(pm.Property__c)
                ? showingMap.get(pm.Property__c)
                : 0;

            // =========================
            // BREAKDOWN
            // =========================
            MatchBreakdown b  = new MatchBreakdown();
            b.areaScore       = pm.Area_Score__c;
            b.budgetScore     = pm.Budget_Score__c;
            b.featuresScore   = pm.Features_Score__c;
            b.locationScore   = pm.Location_Score__c;
            b.roomsScore      = pm.Rooms_Score__c;
            b.typeScore       = pm.Type_Score__c;
            w.breakdown       = b;

            result.add(w);
        }

        // =========================
        // SORT — matchScore DESC
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
    // GET OFFER SUMMARIES
    // =====================================================
@AuraEnabled(cacheable=false)
public static List<OfferSummaryWrapper> getOfferSummaries(
    List<Id> propertyMatchIds
) {
    List<OfferSummaryWrapper> result = new List<OfferSummaryWrapper>();
    if (propertyMatchIds == null || propertyMatchIds.isEmpty()) return result;

    Map<Id, Id> matchToPropertyMap = new Map<Id, Id>();
    for (Property_Match__c pm : [
        SELECT Id, Property__c
        FROM Property_Match__c
        WHERE Id IN :propertyMatchIds
    ]) {
        matchToPropertyMap.put(pm.Id, pm.Property__c);
    }

    Set<Id> propertyIds = new Set<Id>(matchToPropertyMap.values());

    // ✅ Yalnız Offer__c sayılır — Negotiation/CounterOffer xaric
    Map<Id, Integer> offerCountMap = new Map<Id, Integer>();
    for (AggregateResult ar : [
        SELECT Property__c propId, COUNT(Id) cnt
        FROM Offer__c
        WHERE Property__c IN :propertyIds
        GROUP BY Property__c
    ]) {
        offerCountMap.put((Id) ar.get('propId'), (Integer) ar.get('cnt'));
    }

    for (Id matchId : matchToPropertyMap.keySet()) {
        Id propertyId = matchToPropertyMap.get(matchId);
        OfferSummaryWrapper w = new OfferSummaryWrapper();
        w.propertyMatchId = matchId;
        // ✅ Əvvəlki: offers + negs → İndi: yalnız offers
        w.offerCount = offerCountMap.containsKey(propertyId)
            ? offerCountMap.get(propertyId) : 0;
        result.add(w);
    }

    return result;
}
    // =====================================================
    // NOT INTERESTED
    // =====================================================
    @AuraEnabled
    public static void markNotInterested(Id propertyMatchId) {

        Property_Match__c pm = [
            SELECT Id
            FROM Property_Match__c
            WHERE Id = :propertyMatchId
            LIMIT 1
        ];

        pm.Status__c = 'Not Interested';
        update pm;
    }

    // =====================================================
    // RESTORE HIDDEN MATCHES
    // =====================================================
    @AuraEnabled
    public static void restoreHiddenMatches(Id buyerId) {

        List<Property_Match__c> hiddenMatches = [
            SELECT Id, Status__c
            FROM Property_Match__c
            WHERE Buyer__c    = :buyerId
            AND   Status__c   = 'Not Interested'
        ];

        for (Property_Match__c pm : hiddenMatches) {
            pm.Status__c = 'Matched';
        }

        if (!hiddenMatches.isEmpty()) {
            update hiddenMatches;
        }
    }

    // =====================================================
    // SCHEDULE SHOWING
    // =====================================================
    @AuraEnabled
    public static Id scheduleShowing(
        Id propertyMatchId,
        Id buyerId,
        Datetime showingDateTime,
        Integer durationMinutes
    ) {

        Property_Match__c pm = [
            SELECT Id,
                   Property__c,
                   Viewed_Count__c
            FROM Property_Match__c
            WHERE Id = :propertyMatchId
            LIMIT 1
        ];

        Showing__c s           = new Showing__c();
        s.Property__c          = pm.Property__c;
        s.Buyer__c             = buyerId;
        s.Showing_Date_Time__c = showingDateTime;
        s.Duration__c          = durationMinutes;
        s.Status__c            = 'Scheduled';
        insert s;

        pm.Viewed_Count__c =
            (pm.Viewed_Count__c == null ? 0 : pm.Viewed_Count__c) + 1;
        update pm;

        return s.Id;
    }

    // =====================================================
    // SHOWING HISTORY
    // =====================================================
    @AuraEnabled(cacheable=true)
    public static List<Showing__c> getShowingHistory(
        Id propertyId,
        Id buyerId
    ) {
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
            AND   Buyer__c    = :buyerId
            ORDER BY Showing_Date_Time__c DESC
        ];
    }

    // =====================================================
    // PROPERTY PHOTO URL
    // =====================================================
    private static String getPropertyPhotoUrl(Id propertyId) {
        try {
            List<ContentDocumentLink> links = [
                SELECT ContentDocumentId,
                       ContentDocument.Title
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :propertyId
                ORDER BY ContentDocument.CreatedDate ASC
                LIMIT 1
            ];

            if (links.isEmpty()) return '/img/sample-property.jpg';

            Id contentDocId = links[0].ContentDocumentId;

            List<ContentVersion> versions = [
                SELECT Id, VersionData
                FROM ContentVersion
                WHERE ContentDocumentId = :contentDocId
                AND   IsLatest          = true
                LIMIT 1
            ];

            if (versions.isEmpty()) return '/img/sample-property.jpg';

            return '/sfc/servlet.shepherd/version/download/' + versions[0].Id;

        } catch (Exception e) {
            System.debug('Photo fetch error: ' + e.getMessage());
            return '/img/sample-property.jpg';
        }
    }
    // =====================================================
// ADD THESE TWO METHODS TO PropertyMatchController
// =====================================================

    // =====================================================
    // GET PROPERTY PHOTOS (for slider)
    // Returns list of download URLs for all files
    // attached to the given property.
    // =====================================================
    @AuraEnabled(cacheable=true)
    public static List<String> getPropertyPhotos(Id propertyId) {
        List<String> urls = new List<String>();
        try {
            List<ContentDocumentLink> links = [
                SELECT ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :propertyId
                ORDER BY ContentDocument.CreatedDate ASC
            ];

            if (links.isEmpty()) return urls;

            Set<Id> docIds = new Set<Id>();
            for (ContentDocumentLink l : links) {
                docIds.add(l.ContentDocumentId);
            }

            for (ContentVersion cv : [
                SELECT Id
                FROM ContentVersion
                WHERE ContentDocumentId IN :docIds
                AND   IsLatest          = true
                ORDER BY CreatedDate ASC
            ]) {
                urls.add('/sfc/servlet.shepherd/version/download/' + cv.Id);
            }
        } catch (Exception e) {
            System.debug('getPropertyPhotos error: ' + e.getMessage());
        }
        return urls;
    }

    // =====================================================
    // GET PROPERTY OFFERS (for offer kanban)
    // Returns all offers for a given property.
    // ⚠️  IMPORTANT: This method returns ALL buyers' offers.
    // It must ONLY be called from Agent/Seller pages,
    // never from Buyer record pages. Enforce this via
    // page layout or permission set — not just UI logic.
    // =====================================================
    @AuraEnabled(cacheable=false)
public static List<Offer__c> getPropertyOffers(Id propertyId, Id buyerId) {
    return [
        SELECT Id,
               Status__c,
               Offer_Amount__c,
               Buyer__c,
               Buyer__r.Name,
               CreatedDate,
               Financing_Type__c,
               Expiry_Date__c,
               Proposed_Closing_Date__c,
               Current_Round_Number__c
        FROM Offer__c
        WHERE Property__c = :propertyId
          AND Buyer__c    = :buyerId
        ORDER BY CreatedDate DESC
    ];
}
@AuraEnabled(cacheable=false)
public static Map<String, Integer> getPropertyCounts(
    List<Id> propertyMatchIds,
    Id buyerId
) {
    Map<Id, Id> matchToProperty = new Map<Id, Id>();
    for (Property_Match__c pm : [
        SELECT Id, Property__c
        FROM Property_Match__c
        WHERE Id IN :propertyMatchIds
    ]) {
        matchToProperty.put(pm.Id, pm.Property__c);
    }

    Set<Id> propertyIds = new Set<Id>(matchToProperty.values());

    // Ümumi viewed (bütün buyerlar)
    Map<Id, Integer> totalViewedMap = new Map<Id, Integer>();
    for (AggregateResult ar : [
        SELECT Property__c pid, COUNT(Id) cnt
        FROM Showing__c
        WHERE Property__c IN :propertyIds
        GROUP BY Property__c
    ]) {
        totalViewedMap.put((Id)ar.get('pid'), (Integer)ar.get('cnt'));
    }

    // Bu buyer'ın showing sayısı
    Map<Id, Integer> buyerViewedMap = new Map<Id, Integer>();
    for (AggregateResult ar : [
        SELECT Property__c pid, COUNT(Id) cnt
        FROM Showing__c
        WHERE Property__c IN :propertyIds
        AND   Buyer__c = :buyerId
        GROUP BY Property__c
    ]) {
        buyerViewedMap.put((Id)ar.get('pid'), (Integer)ar.get('cnt'));
    }

    // Bu buyer'ın bu property'deki offer sayısı
    Map<Id, Integer> buyerOfferMap = new Map<Id, Integer>();
    for (AggregateResult ar : [
        SELECT Property__c pid, COUNT(Id) cnt
        FROM Offer__c
        WHERE Property__c IN :propertyIds
        AND   Buyer__c = :buyerId
        GROUP BY Property__c
    ]) {
        buyerOfferMap.put((Id)ar.get('pid'), (Integer)ar.get('cnt'));
    }

    // Bu buyer'ın offer'larına bağlı Negotiation sayısı
    Map<Id, Integer> buyerNegMap = new Map<Id, Integer>();
    for (AggregateResult ar : [
        SELECT Offer__r.Property__c pid, COUNT(Id) cnt
        FROM Negotiation__c
        WHERE Offer__r.Property__c IN :propertyIds
        AND   Offer__r.Buyer__c = :buyerId
        GROUP BY Offer__r.Property__c
    ]) {
        buyerNegMap.put((Id)ar.get('pid'), (Integer)ar.get('cnt'));
    }

    Map<String, Integer> result = new Map<String, Integer>();
    for (Id matchId : matchToProperty.keySet()) {
        Id propId = matchToProperty.get(matchId);

        result.put('viewed_'  + matchId,
            totalViewedMap.containsKey(propId) ? totalViewedMap.get(propId) : 0);
        result.put('showing_' + matchId,
            buyerViewedMap.containsKey(propId) ? buyerViewedMap.get(propId) : 0);
        // Bu buyer'ın kendi offer sayısı
        result.put('buyerOffer_' + matchId,
            buyerOfferMap.containsKey(propId) ? buyerOfferMap.get(propId) : 0);
        // Bu buyer'ın offer'ına bağlı negotiation sayısı
        result.put('buyerNeg_' + matchId,
            buyerNegMap.containsKey(propId) ? buyerNegMap.get(propId) : 0);
    }
    return result;
}
// PropertyMatchController.cls - əlavə edin

// Wrapper class for combined Offer + Negotiation items
public class OfferKanbanItem {
    @AuraEnabled public String id;
    @AuraEnabled public String type;           // 'Offer' or 'CounterOffer'
    @AuraEnabled public String status;
    @AuraEnabled public Decimal amount;
    @AuraEnabled public String buyerName;
    @AuraEnabled public DateTime createdDate;
    @AuraEnabled public String parentOfferId;  // Counter-offer hansı offer-a aiddir
}

@AuraEnabled(cacheable=false)
public static List<OfferKanbanItem> getPropertyOffersWithNegotiations(Id propertyId, Id buyerId) {
    List<OfferKanbanItem> result = new List<OfferKanbanItem>();
    
    // 1. Get all offers for this buyer and property
    List<Offer__c> offers = [
        SELECT Id, Status__c, Offer_Amount__c, Buyer__c, Buyer__r.Name, 
               CreatedDate, Financing_Type__c, Expiry_Date__c, 
               Proposed_Closing_Date__c, Current_Round_Number__c
        FROM Offer__c
        WHERE Property__c = :propertyId AND Buyer__c = :buyerId
        ORDER BY CreatedDate DESC
    ];
    
    // Map to store offer Id -> offer for later reference
    Map<Id, Offer__c> offerMap = new Map<Id, Offer__c>(offers);
    
    // Add offers to result
    for (Offer__c offer : offers) {
        OfferKanbanItem item = new OfferKanbanItem();
        item.id = offer.Id;
        item.type = 'Offer';
        item.status = offer.Status__c;
        item.amount = offer.Offer_Amount__c;
        item.buyerName = offer.Buyer__r?.Name;
        item.createdDate = offer.CreatedDate;
        item.parentOfferId = null;
        result.add(item);
    }
    
    // 2. Get all negotiations (counter offers) for this buyer's offers
    if (!offerMap.keySet().isEmpty()) {
        List<Negotiation__c> negotiations = [
            SELECT Id, Status__c, Amount__c, Offer__c, Offer__r.Buyer__r.Name,
                   CreatedDate, Offer__r.Buyer__c
            FROM Negotiation__c
            WHERE Offer__c IN :offerMap.keySet()
              AND Offer__r.Buyer__c = :buyerId
            ORDER BY CreatedDate DESC
        ];
        
        for (Negotiation__c neg : negotiations) {
            OfferKanbanItem item = new OfferKanbanItem();
            item.id = neg.Id;
            item.type = 'CounterOffer';
            item.status = neg.Status__c;
            item.amount = neg.Amount__c;
            item.buyerName = neg.Offer__r.Buyer__r?.Name;
            item.createdDate = neg.CreatedDate;
            item.parentOfferId = neg.Offer__c;
            result.add(item);
        }
    }
    
    // Sort by created date desc
for (Integer i = 0; i < result.size() - 1; i++) {
    for (Integer j = i + 1; j < result.size(); j++) {
        if (result[j].createdDate > result[i].createdDate) {
            OfferKanbanItem tmp = result[i];
            result[i] = result[j];
            result[j] = tmp;
        }
    }
}
    
    return result;
}
}