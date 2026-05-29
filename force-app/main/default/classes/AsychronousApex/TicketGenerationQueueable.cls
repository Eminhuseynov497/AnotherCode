public class TicketGenerationQueueable implements Queueable {
    private Set<Id> eventIds;

    public TicketGenerationQueueable(Set<Id> eventIds) {
        this.eventIds = eventIds;
    }

    public void execute(QueueableContext context) {
        TicketGenerationBatch.runBatch(eventIds);
    }
}