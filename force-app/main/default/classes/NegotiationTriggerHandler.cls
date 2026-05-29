public class NegotiationTriggerHandler {

    public static void afterUpdate(
        List<Negotiation__c> newList,
        Map<Id, Negotiation__c> oldMap
    ) {
        Map<Id, Negotiation__c> acceptedNegsByOfferId = new Map<Id, Negotiation__c>();

        for (Negotiation__c neg : newList) {
            Negotiation__c old = oldMap.get(neg.Id);
            if (neg.Status__c == 'Accepted' && old.Status__c != 'Accepted') {
                acceptedNegsByOfferId.put(neg.Offer__c, neg);
            }
        }

        if (acceptedNegsByOfferId.isEmpty()) return;

        List<Offer__c> offersToAccept = [
            SELECT Id, Status__c, Offer_Amount__c
            FROM Offer__c
            WHERE Id IN :acceptedNegsByOfferId.keySet()
              AND Status__c != 'Accepted'
        ];

        if (offersToAccept.isEmpty()) return;

        for (Offer__c o : offersToAccept) {
            Negotiation__c neg = acceptedNegsByOfferId.get(o.Id);
            o.Status__c = 'Accepted';

            // Counter_Offer_Amount__c → Amount__c (sənin field adın)
            if (neg.Amount__c != null) {
                o.Offer_Amount__c = neg.Amount__c;
            }
        }

        update offersToAccept;
    }
}