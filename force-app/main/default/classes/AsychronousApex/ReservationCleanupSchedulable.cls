public class ReservationCleanupSchedulable implements Schedulable {
    public void execute(SchedulableContext sc) {
        Set<Id> affectedEventIds = new Set<Id>();
        for (Ticket__c t : [
            SELECT Sport_Event__c
            FROM Ticket__c
            WHERE Status__c = 'Reserved'
              AND Reserved_Until__c < :System.now()
            LIMIT 10000
        ]) {
            affectedEventIds.add(t.Sport_Event__c);
        }

        TicketInventoryService.releaseExpiredReservations();

        if (!affectedEventIds.isEmpty()) {
            TicketInventoryService.updateEventAvailabilityStatus(affectedEventIds);
        }
    }
}