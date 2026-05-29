trigger PurchaseOrderTrigger on Purchase_Order__c (after update) {
    
    if (Trigger.isAfter && Trigger.isUpdate) {
        Set<Id> eventIdsToUpdate = new Set<Id>();
        
        for (Purchase_Order__c order : Trigger.new) {
            Purchase_Order__c old = Trigger.oldMap.get(order.Id);

            if (order.Status__c == 'Confirmed' && old.Status__c != 'Confirmed') {
                if (order.Sport_Event__c != null) {
                    eventIdsToUpdate.add(order.Sport_Event__c);
                }
            }
        }
        
        if (!eventIdsToUpdate.isEmpty()) {
            System.enqueueJob(new EventAvailabilityUpdateJob(eventIdsToUpdate));
        }
    }
}