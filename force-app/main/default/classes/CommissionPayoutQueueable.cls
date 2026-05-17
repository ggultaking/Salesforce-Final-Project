public class CommissionPayoutQueueable implements Queueable {

    private Set<Id> commissionIds;

    public CommissionPayoutQueueable(Set<Id> ids) {
        this.commissionIds = ids;
    }

    public void execute(QueueableContext context) {
if (commissionIds == null || commissionIds.isEmpty()) return;
        List<Commission__c> commissions = [
            SELECT Id, Status__c
            FROM Commission__c
            WHERE Id IN :commissionIds
        ];

        for (Commission__c c : commissions) {
            c.Status__c = 'Paid';
            c.Payment_Date__c = Date.today();
        }

        update commissions;
    }
}