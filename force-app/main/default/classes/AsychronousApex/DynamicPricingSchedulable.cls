global class DynamicPricingSchedulable implements Schedulable {
    
    private Set<Id> specificEventIds;
    public DynamicPricingSchedulable() {}
    public DynamicPricingSchedulable(Set<Id> eventIds) {
        this.specificEventIds = eventIds;
    }
    
    global void execute(SchedulableContext sc) {
        Set<Id> eventIds = new Set<Id>();
        
        if (specificEventIds != null && !specificEventIds.isEmpty()) {
            eventIds = specificEventIds;
        } else {
            DateTime now = System.now();
            DateTime thirtyDaysFromNow = now.addDays(30);
            
            for (Sport_Event__c ev : [
                SELECT Id FROM Sport_Event__c
                WHERE Date_Time__c > :now
                  AND Date_Time__c <= :thirtyDaysFromNow
                  AND Status__c IN ('On Sale', 'Scheduled')
            ]) {
                eventIds.add(ev.Id);
            }
        }
        
        if (!eventIds.isEmpty()) {
            DynamicPricingService.recalculateEventPrices(eventIds);
        }
    }
}