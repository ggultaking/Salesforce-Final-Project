public class TransactionStatusValidator {
public class CustomException extends Exception {}
    private static Map<String, Integer> order = new Map<String, Integer>{
        'Draft' => 1,
        'Pending' => 2,
        'In Progress' => 3,
        'Closed' => 4
    };

    public static void validate(String oldStatus, String newStatus) {

        if (oldStatus == null || newStatus == null) return;

        Integer oldIndex = order.get(oldStatus);
        Integer newIndex = order.get(newStatus);

        if (oldIndex == null || newIndex == null) return;

        if (newIndex < oldIndex) {
            throw new CustomException(
                'Invalid status transition from ' + oldStatus + ' to ' + newStatus
            );
        }
    }
}