public with sharing class EventAvailabilityUpdateJob implements Queueable {
    
    private Set<Id> eventIds;
    
    public EventAvailabilityUpdateJob(Set<Id> eventIds) {
        this.eventIds = eventIds;
    }
    
    public void execute(QueueableContext context) {
        TicketInventoryService.updateEventAvailabilityStatus(eventIds);
    }
}