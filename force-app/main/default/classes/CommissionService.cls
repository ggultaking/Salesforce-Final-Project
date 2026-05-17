public class CommissionService {

    // =====================================
    // 1. CREATE COMMISSIONS (CORE LOGIC)
    // =====================================
    public static void calculateCommissions(Set<Id> transactionIds) {

        if (transactionIds == null || transactionIds.isEmpty()) return;

        List<Transaction__c> transactions = [
            SELECT Id, Property__c, Property__r.Commission_Rate__c, Buyer__c
FROM Transaction__c
            WHERE Id IN :transactionIds
        ];

        if (transactions.isEmpty()) return;
        Set<Id> existingTransactionIds = new Set<Id>();

for (Commission__c c : [
    SELECT Transaction__c
    FROM Commission__c
    WHERE Transaction__c IN :transactionIds
]) {
    existingTransactionIds.add(c.Transaction__c);
}

        List<Commission__c> commissions = new List<Commission__c>();

   for (Transaction__c t : transactions) {
    Decimal rate = 0.03;

if (t.Property__r != null && t.Property__r.Commission_Rate__c != null) {
    rate = t.Property__r.Commission_Rate__c;
}

Decimal total = 100000 * rate;
Decimal half = total / 2;

    // DUPLICATE PROTECTION
    if (existingTransactionIds.contains(t.Id)) {
        continue;
    }

    if (t.Property__c == null) continue;

    // Listing commission
    commissions.add(new Commission__c(
        Transaction__c = t.Id,
        Agent_Role__c = 'Listing',
        Status__c = 'Pending'
    ));

    // Buying commission
    commissions.add(new Commission__c(
        Transaction__c = t.Id,
        Agent_Role__c = 'Buyer',
        Status__c = 'Pending'
    ));
}

        if (!commissions.isEmpty()) {
            insert commissions;
        }
    }

    // =====================================
    // 2. APPROVE COMMISSION
    // =====================================
    public static void approveCommission(Id commissionId) {
 if (!Schema.sObjectType.Commission__c.isUpdateable()) {
    throw new AuraHandledException('No permission to approve commission');
}
        if (commissionId == null) return;

        Commission__c c = [
            SELECT Id, Status__c, Approved_By__c
            FROM Commission__c
            WHERE Id = :commissionId
            LIMIT 1
        ];

        c.Status__c = 'Approved';
        c.Approved_By__c = UserInfo.getUserId();
        c.Payment_Date__c = Date.today();

        update c;
    }

    // =====================================
    // 3. AGENT EARNINGS (USES FORMULA FIELDS)
    // =====================================
    public static Decimal getAgentEarnings(Id agentId, Date startDate, Date endDate) {

        if (agentId == null) return 0;

        Decimal total = 0;

        for (Commission__c c : [
            SELECT Net_Amount__c
            FROM Commission__c
         WHERE Agent__c = :agentId
AND Status__c = 'Approved'
AND Payment_Date__c >= :startDate
AND Payment_Date__c <= :endDate
        ]) {
            if (c.Net_Amount__c != null) {
                total += c.Net_Amount__c;
            }
        }

        return total;
    }
}