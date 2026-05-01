public with sharing class PropertyMatchScheduler implements Schedulable  {
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new PropertyMatchBatchJob(), 50);
    }
    public PropertyMatchScheduler() {

    }
}