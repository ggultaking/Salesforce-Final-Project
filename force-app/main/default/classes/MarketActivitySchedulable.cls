global class MarketActivitySchedulable implements Schedulable {

    global void execute(SchedulableContext sc) {

        Date lastWeek = Date.today().addDays(-7);

        List<Property__c> properties = [
            SELECT Id, Status__c, CreatedDate, Asking_Price__c
            FROM Property__c
            WHERE CreatedDate >= :lastWeek
        ];

        Integer newListings = 0;
        Integer sold = 0;
        Integer priceChanges = 0;

        for (Property__c p : properties) {

            if (p.Status__c == 'Sold') {
                sold++;
            }

            if (p.CreatedDate >= lastWeek) {
                newListings++;
            }

            if (p.Asking_Price__c != null) {
                priceChanges++;
            }
        }

        System.debug('Market Report');
        System.debug('New Listings: ' + newListings);
        System.debug('Sold: ' + sold);
        System.debug('Price Changes: ' + priceChanges);
    }
}