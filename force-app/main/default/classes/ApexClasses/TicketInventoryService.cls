public with sharing class TicketInventoryService {
    public static void generateTickets(Set<Id> eventIds) {
        if (eventIds == null || eventIds.isEmpty()) return;

        List<Sport_Event__c> events = [
            SELECT Id, Stadium__c, Date_Time__c, Season__c,
                (SELECT Id, Name FROM Tickets__r LIMIT 1)
            FROM Sport_Event__c
            WHERE Id IN :eventIds
        ];

        Map<Id, List<Stadium_Section__c>> stadiumSectionsMap = new Map<Id, List<Stadium_Section__c>>();
        Set<Id> stadiumIds = new Set<Id>();
        for (Sport_Event__c evt : events) {
            stadiumIds.add(evt.Stadium__c);
        }

        List<Stadium_Section__c> sections = [
            SELECT Id, Stadium__c, Row_Count__c, Seats_Per_Row__c, Base_Price__c, Is_Active__c
            FROM Stadium_Section__c
            WHERE Stadium__c IN :stadiumIds AND Is_Active__c = true
        ];

        for (Stadium_Section__c sec : sections) {
            if (!stadiumSectionsMap.containsKey(sec.Stadium__c)) {
                stadiumSectionsMap.put(sec.Stadium__c, new List<Stadium_Section__c>());
            }
            stadiumSectionsMap.get(sec.Stadium__c).add(sec);
        }

        List<Ticket__c> ticketsToInsert = new List<Ticket__c>();
        for (Sport_Event__c evt : events) {
            if (!evt.Tickets__r.isEmpty()) continue;

            List<Stadium_Section__c> eventSections = stadiumSectionsMap.get(evt.Stadium__c);
            if (eventSections == null) continue;

            for (Stadium_Section__c sec : eventSections) {
                Integer rowCount = sec.Row_Count__c != null ? sec.Row_Count__c.intValue() : 0;
                Integer seatsPerRow = sec.Seats_Per_Row__c != null ? sec.Seats_Per_Row__c.intValue() : 0;
                for (Integer r = 1; r <= rowCount; r++) {
                    for (Integer s = 1; s <= seatsPerRow; s++) {
                        Ticket__c t = new Ticket__c();
                        t.Sport_Event__c = evt.Id;
                        t.Stadium_Section__c = sec.Id;
                        t.Row_Number__c = r;
                        t.Seat_Number__c = s;
                        t.Base_Price__c = sec.Base_Price__c;
                        t.Status__c = 'Available';
                        t.Seat_Key__c = evt.Id + '-' + sec.Id + '-' + r + '-' + s;
                        ticketsToInsert.add(t);
                    }
                }
            }
        }

        if (!ticketsToInsert.isEmpty()) {
            insert ticketsToInsert;
        }
    }

    public static void reserveTickets(Set<Id> ticketIds, Datetime holdUntil) {
        if (ticketIds == null || ticketIds.isEmpty() || holdUntil == null) return;

        List<Ticket__c> tickets = [
            SELECT Id, Status__c
            FROM Ticket__c
            WHERE Id IN :ticketIds AND Status__c = 'Available'
            FOR UPDATE
        ];

        for (Ticket__c t : tickets) {
            t.Status__c = 'Reserved';
            t.Reserved_Until__c = holdUntil;
        }

        if (!tickets.isEmpty()) {
            update tickets;
        }
    }

    public static void confirmReservedTickets(Id orderId, Set<Id> ticketIds) {
        if (orderId == null || ticketIds == null || ticketIds.isEmpty()) return;

        Purchase_Order__c order = [
            SELECT Id, Sport_Event__c
            FROM Purchase_Order__c
            WHERE Id = :orderId
        ];

        List<Ticket__c> tickets = [
            SELECT Id, Sport_Event__c, Status__c
            FROM Ticket__c
            WHERE Id IN :ticketIds
            FOR UPDATE
        ];

        for (Ticket__c t : tickets) {
            if (t.Sport_Event__c != order.Sport_Event__c) {
                throw new TicketInventoryException('Ticket ' + t.Id + ' does not belong to the event of this order.');
            }
            if (t.Status__c != 'Reserved') {
                throw new TicketInventoryException('Ticket ' + t.Id + ' is not in Reserved status.');
            }
        }

        for (Ticket__c t : tickets) {
            t.Status__c = 'Sold';
            t.Purchase_Order__c = orderId;
            t.Reserved_Until__c = null;
        }

        update tickets;
    }

    public static void releaseExpiredReservations() {
        List<Ticket__c> expired = [
            SELECT Id
            FROM Ticket__c
            WHERE Status__c = 'Reserved' AND Reserved_Until__c < :System.now()
            LIMIT 10000
        ];

        if (!expired.isEmpty()) {
            for (Ticket__c t : expired) {
                t.Status__c = 'Available';
                t.Reserved_Until__c = null;
            }
            update expired;
        }
    }

    public static List<Ticket__c> getSeatMapData(Id eventId, Id sectionId) {
        if (eventId == null || sectionId == null) return new List<Ticket__c>();

        return [
            SELECT Id, Row_Number__c, Seat_Number__c, Seat_Label__c, Seat_Key__c,
                   Status__c, Base_Price__c, Dynamic_Price__c, QR_Code__c,
                   Is_Season_Pass_Ticket__c, Checked_In_At__c
            FROM Ticket__c
            WHERE Sport_Event__c = :eventId
              AND Stadium_Section__c = :sectionId
            ORDER BY Row_Number__c, Seat_Number__c
        ];
    }

    public static void updateEventAvailabilityStatus(Set<Id> eventIds) {
        if (eventIds == null || eventIds.isEmpty()) return;

        List<AggregateResult> counts = [
            SELECT Sport_Event__c eventId, COUNT(Id) availableCount
            FROM Ticket__c
            WHERE Sport_Event__c IN :eventIds AND Status__c = 'Available'
            GROUP BY Sport_Event__c
        ];

        Map<Id, Integer> availableMap = new Map<Id, Integer>();
        for (AggregateResult ar : counts) {
            Id eId = (Id)ar.get('eventId');
            Integer cnt = Integer.valueOf(ar.get('availableCount'));
            availableMap.put(eId, cnt);
        }

        List<Sport_Event__c> events = [
            SELECT Id, Status__c
            FROM Sport_Event__c
            WHERE Id IN :eventIds
            FOR UPDATE
        ];

        List<Sport_Event__c> eventsToUpdate = new List<Sport_Event__c>();
        for (Sport_Event__c evt : events) {
            Integer avail = availableMap.containsKey(evt.Id) ? availableMap.get(evt.Id) : 0;
            String currentStatus = evt.Status__c;

            if (avail == 0 && currentStatus != 'Sold Out' && currentStatus != 'Completed' && currentStatus != 'Cancelled') {
                evt.Status__c = 'Sold Out';
                eventsToUpdate.add(evt);
            } else if (avail > 0 && currentStatus == 'Sold Out') {
                evt.Status__c = 'On Sale';
                eventsToUpdate.add(evt);
            }
        }

        if (!eventsToUpdate.isEmpty()) {
            update eventsToUpdate;
        }
    }

    public class TicketInventoryException extends Exception {}
}