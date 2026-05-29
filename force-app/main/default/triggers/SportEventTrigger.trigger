trigger SportEventTrigger on Sport_Event__c (after update) {
    
    if (Trigger.isAfter && Trigger.isUpdate) {
        Set<Id> eventIdsForRecalc = new Set<Id>();
        
        for (Sport_Event__c ev : Trigger.new) {
            Sport_Event__c old = Trigger.oldMap.get(ev.Id);
            
            if (ev.Status__c == 'On Sale' && old.Status__c != 'On Sale') {
                eventIdsForRecalc.add(ev.Id);
            }
            else if (ev.Event_Type__c != old.Event_Type__c) {
                eventIdsForRecalc.add(ev.Id);
            }
        }
        
        if (!eventIdsForRecalc.isEmpty()) {
            System.enqueueJob(new DynamicPricingSchedulable(eventIdsForRecalc));
        }
    }
}