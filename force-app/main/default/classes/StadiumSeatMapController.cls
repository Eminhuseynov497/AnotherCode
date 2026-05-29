public with sharing class StadiumSeatMapController {
    @AuraEnabled(cacheable=false)
    public static List<SectionSummary> getEventSections(Id eventId) {
        Sport_Event__c evt = [SELECT Id, Stadium__c FROM Sport_Event__c WHERE Id = :eventId LIMIT 1];
        if (evt.Stadium__c == null) return new List<SectionSummary>();

        List<AggregateResult> aggr = [
            SELECT Stadium_Section__c secId, COUNT(Id) availCount, MIN(Dynamic_Price__c) minPrice
            FROM Ticket__c
            WHERE Sport_Event__c = :eventId AND Status__c = 'Available'
            GROUP BY Stadium_Section__c
        ];
        Map<Id, SectionSummary> mapBySecId = new Map<Id, SectionSummary>();
        for (AggregateResult ar : aggr) {
            Id secId = (Id)ar.get('secId');
            Integer cnt = Integer.valueOf(ar.get('availCount'));
            Decimal minP = (Decimal)ar.get('minPrice');
            mapBySecId.put(secId, new SectionSummary(secId, cnt, minP));
        }

        List<Stadium_Section__c> sections = [
            SELECT Id, Name, Category__c, Color_Code__c, Sort_Order__c
            FROM Stadium_Section__c
            WHERE Stadium__c = :evt.Stadium__c AND Is_Active__c = true
            ORDER BY Sort_Order__c
        ];

        List<SectionSummary> result = new List<SectionSummary>();
        for (Stadium_Section__c sec : sections) {
            SectionSummary s = mapBySecId.containsKey(sec.Id) ? mapBySecId.get(sec.Id) : new SectionSummary(sec.Id, 0, null);
            s.name = sec.Name;
            s.category = sec.Category__c;
            s.colorCode = sec.Color_Code__c;
            result.add(s);
        }
        return result;
    }

    @AuraEnabled(cacheable=false)
    public static List<TicketSeat> getSeatsForSection(Id eventId, Id sectionId) {
        List<Ticket__c> tickets = [
            SELECT Id, Row_Number__c, Seat_Number__c, Seat_Label__c, Status__c, Dynamic_Price__c, Is_Season_Pass_Ticket__c
            FROM Ticket__c
            WHERE Sport_Event__c = :eventId AND Stadium_Section__c = :sectionId
            ORDER BY Row_Number__c, Seat_Number__c
        ];
        List<TicketSeat> seats = new List<TicketSeat>();
        for (Ticket__c t : tickets) {
            seats.add(new TicketSeat(t));
        }
        return seats;
    }

    @AuraEnabled
    public static String reserveSelectedSeats(List<Id> ticketIds) {
        if (ticketIds.size() > 6) {
            throw new AuraHandledException('You can select at most 6 seats.');
        }
        Set<Id> idSet = new Set<Id>(ticketIds);
        Datetime holdUntil = Datetime.now().addMinutes(15);

        List<Ticket__c> tickets = [
            SELECT Id, Status__c
            FROM Ticket__c
            WHERE Id IN :idSet
            FOR UPDATE
        ];
        for (Ticket__c t : tickets) {
            if (t.Status__c != 'Available') {
                throw new AuraHandledException('One or more seats are no longer available.');
            }
            t.Status__c = 'Reserved';
            t.Reserved_Until__c = holdUntil;
        }
        update tickets;
        return holdUntil.format('yyyy-MM-dd HH:mm:ss');
    }

    @AuraEnabled
    public static void releaseReservation(List<Id> ticketIds) {
        List<Ticket__c> tickets = [
            SELECT Id, Status__c
            FROM Ticket__c
            WHERE Id IN :ticketIds AND Status__c = 'Reserved'
            FOR UPDATE
        ];
        for (Ticket__c t : tickets) {
            t.Status__c = 'Available';
            t.Reserved_Until__c = null;
        }
        if (!tickets.isEmpty()) update tickets;
    }

    public class SectionSummary {
        @AuraEnabled public Id sectionId;
        @AuraEnabled public String name;
        @AuraEnabled public String category;
        @AuraEnabled public Integer availableCount;
        @AuraEnabled public Decimal startingPrice;
        @AuraEnabled public String colorCode;
        public SectionSummary(Id sectionId, Integer availableCount, Decimal startingPrice) {
            this.sectionId = sectionId;
            this.availableCount = availableCount;
            this.startingPrice = startingPrice;
        }
    }

    public class TicketSeat {
        @AuraEnabled public Id ticketId;
        @AuraEnabled public Integer row;
        @AuraEnabled public Integer seat;
        @AuraEnabled public String label;
        @AuraEnabled public String status;
        @AuraEnabled public Decimal dynamicPrice;
        @AuraEnabled public Boolean isSeasonPass;
        public TicketSeat(Ticket__c t) {
            this.ticketId = t.Id;
            this.row = Integer.valueOf(t.Row_Number__c);
            this.seat = Integer.valueOf(t.Seat_Number__c);
            this.label = t.Seat_Label__c;
            this.status = t.Status__c;
            this.dynamicPrice = t.Dynamic_Price__c;
            this.isSeasonPass = t.Is_Season_Pass_Ticket__c;
        }
    }
}