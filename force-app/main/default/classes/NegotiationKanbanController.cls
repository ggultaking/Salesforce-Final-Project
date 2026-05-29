public with sharing class NegotiationKanbanController {

    // =====================================================
    // WRAPPER — Offer + Negotiations birlikdə
    // =====================================================
    public class OfferCardWrapper {
        @AuraEnabled public Id      offerId;
        @AuraEnabled public String  buyerName;
        @AuraEnabled public String  buyerEmail;
        @AuraEnabled public Decimal offerAmount;
        @AuraEnabled public String  status;
        @AuraEnabled public Integer roundNumber;
        @AuraEnabled public String  financingType;
        @AuraEnabled public String  expiryDate;
        @AuraEnabled public String  closingDate;
        @AuraEnabled public String  createdDate;
        @AuraEnabled public List<NegotiationRound> rounds;
        @AuraEnabled public Decimal latestAmount;
        @AuraEnabled public String  latestProposedBy;
    }

    public class NegotiationRound {
        @AuraEnabled public Id      negId;
        @AuraEnabled public Integer roundNumber;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String  proposedBy;
        @AuraEnabled public String  proposedByName;
        @AuraEnabled public String  status;
        @AuraEnabled public String  conditions;
        @AuraEnabled public String  responseDeadline;
        @AuraEnabled public String  createdDate;
    }

    // =====================================================
    // GET ALL OFFERS FOR A PROPERTY (Seller view)
    // =====================================================
    @AuraEnabled(cacheable=false)
    public static List<OfferCardWrapper> getPropertyOffersForSeller(Id propertyId) {
        List<OfferCardWrapper> result = new List<OfferCardWrapper>();

        List<Offer__c> offers = [
            SELECT Id,
                   Status__c,
                   Offer_Amount__c,
                   Buyer__c,
                   Buyer__r.Name,
                   Buyer__r.Email__c,
                   CreatedDate,
                   Financing_Type__c,
                   Expiry_Date__c,
                   Proposed_Closing_Date__c,
                   Current_Round_Number__c
            FROM Offer__c
            WHERE Property__c = :propertyId
            ORDER BY CreatedDate DESC
        ];

        if (offers.isEmpty()) return result;

        Set<Id> offerIds = new Set<Id>();
        for (Offer__c o : offers) offerIds.add(o.Id);

        Map<Id, List<Negotiation__c>> negMap = new Map<Id, List<Negotiation__c>>();
        for (Id oid : offerIds) negMap.put(oid, new List<Negotiation__c>());

        for (Negotiation__c n : [
            SELECT Id,
                   Offer__c,
                   Round_Number__c,
                   Amount__c,
                   Proposed_By__c,
                   Proposed_By_Name__c,
                   Status__c,
                   Conditions_Changed__c,
                   Response_Deadline__c,
                   CreatedDate
            FROM Negotiation__c
            WHERE Offer__c IN :offerIds
            ORDER BY Round_Number__c ASC
        ]) {
            if (negMap.containsKey(n.Offer__c)) {
                negMap.get(n.Offer__c).add(n);
            }
        }

        for (Offer__c o : offers) {
            OfferCardWrapper w = new OfferCardWrapper();
            w.offerId       = o.Id;
            w.buyerName     = o.Buyer__r?.Name;
            w.buyerEmail    = o.Buyer__r?.Email__c;
            w.offerAmount   = o.Offer_Amount__c;
            w.status        = o.Status__c;
            w.roundNumber   = o.Current_Round_Number__c != null
                ? Integer.valueOf(o.Current_Round_Number__c) : 1;
            w.financingType = o.Financing_Type__c;
            
            w.expiryDate    = o.Expiry_Date__c != null
                ? o.Expiry_Date__c.format()
                : null;
            w.closingDate   = o.Proposed_Closing_Date__c != null
                ? o.Proposed_Closing_Date__c.format()
                : null;
            w.createdDate   = o.CreatedDate != null
                ? o.CreatedDate.format('dd MMM yyyy') : null;

            List<NegotiationRound> rounds = new List<NegotiationRound>();
            List<Negotiation__c> negs = negMap.get(o.Id);

            Decimal latestAmt = o.Offer_Amount__c;
            String  latestBy  = 'Buyer';

            for (Negotiation__c n : negs) {
                NegotiationRound r = new NegotiationRound();
                r.negId          = n.Id;
                r.roundNumber    = n.Round_Number__c != null
                    ? Integer.valueOf(n.Round_Number__c) : 0;
                r.amount         = n.Amount__c;
                r.proposedBy     = n.Proposed_By__c;
                r.proposedByName = n.Proposed_By_Name__c;
                r.status         = n.Status__c;
                r.conditions     = n.Conditions_Changed__c;
                
                r.responseDeadline = n.Response_Deadline__c != null
                    ? n.Response_Deadline__c.format()
                    : null;
                r.createdDate    = n.CreatedDate != null
                    ? n.CreatedDate.format('dd MMM yyyy') : null;
                rounds.add(r);

                if (n.Amount__c != null) latestAmt = n.Amount__c;
                latestBy = n.Proposed_By__c;
            }

            w.rounds           = rounds;
            w.latestAmount     = latestAmt;
            w.latestProposedBy = latestBy;
            result.add(w);
        }

        return result;
    }

    // =====================================================
    // SELLER COUNTER OFFER — yeni Negotiation yarat
    // =====================================================
    @AuraEnabled
    public static void createSellerCounterOffer(
        Id offerId,
        Decimal counterAmount,
        String  conditions,
        String  responseDeadlineStr
    ) {
        Offer__c offer = [
            SELECT Id, Current_Round_Number__c, Buyer__r.Name, Property__c
            FROM Offer__c
            WHERE Id = :offerId
            LIMIT 1
        ];

        Integer nextRound = offer.Current_Round_Number__c != null
            ? Integer.valueOf(offer.Current_Round_Number__c) + 1
            : 2;

        Date deadline = null;
        if (String.isNotBlank(responseDeadlineStr)) {
            try {
                String dateStr = responseDeadlineStr;
                if (dateStr.contains('T')) {
                    dateStr = dateStr.split('T')[0];
                }
                if (dateStr.contains('Z')) {
                    dateStr = dateStr.replace('Z', '');
                }
                deadline = Date.valueOf(dateStr);
            } catch (Exception e) {
                deadline = Date.today().addDays(7);
            }
        }

        Negotiation__c neg = new Negotiation__c();
        neg.Offer__c              = offerId;
        neg.Amount__c             = counterAmount;
        neg.Round_Number__c       = nextRound;
        neg.Proposed_By__c        = 'Seller';
        neg.Proposed_By_Name__c   = UserInfo.getName();
        neg.Status__c             = 'Countered';
        neg.Conditions_Changed__c = conditions;
        neg.Response_Deadline__c  = deadline;
        insert neg;

        offer.Current_Round_Number__c = nextRound;
        offer.Status__c               = 'Countered';
        update offer;
    }

    // =====================================================
    // UPDATE OFFER STATUS (Accept / Reject)
    // =====================================================
    @AuraEnabled
    public static void updateOfferStatus(Id offerId, String newStatus) {
        Offer__c offer = [
            SELECT Id, Status__c
            FROM Offer__c
            WHERE Id = :offerId
            LIMIT 1
        ];
        offer.Status__c = newStatus;
        update offer;
    }
}