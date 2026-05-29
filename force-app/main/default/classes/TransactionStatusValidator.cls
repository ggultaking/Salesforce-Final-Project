public class TransactionStatusValidator {
    public class CustomException extends Exception {}

    private static Map<String, Integer> order = new Map<String, Integer>{
        'Pipeline'       => 1,
        'Under Contract' => 2,
        'Inspection'     => 3,
        'Appraisal'      => 4,
        'Closing'        => 5,
        'Closed'         => 6
    };

    public static void validate(String oldStatus, String newStatus) {
        if (oldStatus == null || newStatus == null) return;

        Integer oldIndex = order.get(oldStatus);
        Integer newIndex = order.get(newStatus);

        // Bilinməyən status → burax (null-safe)
        if (oldIndex == null || newIndex == null) return;

        if (newIndex < oldIndex) {
            throw new CustomException(
                'Invalid status transition from ' + oldStatus + ' to ' + newStatus
            );
        }
    }
}