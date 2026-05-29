public class TicketGenerationBatch implements Database.Batchable<SObject>, Database.Stateful {
    private Set<Id> eventIds;
    public TicketGenerationBatch(Set<Id> eventIds) {
        this.eventIds = eventIds;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id
            FROM Sport_Event__c
            WHERE Id IN :eventIds
              AND Status__c = 'On Sale'
              AND Id NOT IN (SELECT Sport_Event__c FROM Ticket__c)
        ]);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        Set<Id> scopedEventIds = new Set<Id>();
        for (SObject obj : scope) {
            scopedEventIds.add(obj.Id);
        }
        if (!scopedEventIds.isEmpty()) {
            TicketInventoryService.generateTickets(scopedEventIds);
        }
    }

    public void finish(Database.BatchableContext bc) {
        if (!eventIds.isEmpty()) {
            SeasonPassService.reserveSeasonPassSeatsForNewEvents(eventIds);
        }
    }
    
    public static Id runBatch(Set<Id> eventIds) {
        return Database.executeBatch(new TicketGenerationBatch(eventIds), 1);
    }
}