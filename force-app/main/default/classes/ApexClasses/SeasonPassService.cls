public with sharing class SeasonPassService {

    /**
     * @param teamId
     * @param sectionId
     * @param season
     * @param paymentPlan
     * @return цена абонемента
     */
    public static Decimal calculateSeasonPassPrice(Id teamId, Id sectionId, String season, String paymentPlan) {
        if (teamId == null || sectionId == null || String.isBlank(season)) {
            return 0.0;
        }

        Team__c team = [SELECT Id, Home_Stadium__c FROM Team__c WHERE Id = :teamId LIMIT 1];
        Stadium_Section__c section = [SELECT Id, Base_Price__c, Stadium__c FROM Stadium_Section__c WHERE Id = :sectionId LIMIT 1];

        if (team.Home_Stadium__c != section.Stadium__c) {
            throw new SeasonPassException('Секция не принадлежит домашнему стадиону выбранной команды');
        }

        List<Sport_Event__c> events = [
            SELECT Id
            FROM Sport_Event__c
            WHERE Home_Team__c = :teamId
              AND Season__c = :season
              AND Date_Time__c > :System.now()
              AND Status__c NOT IN ('Cancelled', 'Completed')
        ];

        Decimal totalBasePrice = section.Base_Price__c * events.size();

        Decimal planMultiplier = (paymentPlan == 'Monthly') ? 1.05 : 1.0;

        return (totalBasePrice * planMultiplier).setScale(2, System.RoundingMode.HALF_UP);
    }

    /**
     * @param seasonPassId
     */
    public static void reserveFutureSeasonPassSeats(Id seasonPassId) {
        if (seasonPassId == null) return;

        Season_Pass__c sp = [
            SELECT Id, Team__c, Season__c, Stadium_Section__c, Preferred_Row__c, Preferred_Seats__c, Start_Date__c, End_Date__c
            FROM Season_Pass__c
            WHERE Id = :seasonPassId
        ];

        List<Sport_Event__c> events = [
            SELECT Id
            FROM Sport_Event__c
            WHERE Home_Team__c = :sp.Team__c
              AND Season__c = :sp.Season__c
              AND Date_Time__c > :System.now()
              AND Date_Time__c >= :sp.Start_Date__c
              AND Date_Time__c <= :sp.End_Date__c
              AND Status__c NOT IN ('Cancelled', 'Completed')
        ];

        if (events.isEmpty()) return;

        Set<Id> eventIds = new Set<Id>();
        for (Sport_Event__c evt : events) {
            eventIds.add(evt.Id);
        }

        reserveSeatsForEvents(sp, eventIds);
    }

    /**
     * @param seasonPassId ID Season_Pass__c
     */
    public static void releaseFutureSeasonPassSeats(Id seasonPassId) {
        if (seasonPassId == null) return;

        List<Ticket__c> tickets = [
            SELECT Id, Sport_Event__c
            FROM Ticket__c
            WHERE Season_Pass__c = :seasonPassId
              AND Status__c = 'Reserved'
        ];

        if (tickets.isEmpty()) return;

        for (Ticket__c t : tickets) {
            t.Status__c = 'Available';
            t.Is_Season_Pass_Ticket__c = false;
            t.Season_Pass__c = null;
            t.Reserved_Until__c = null;
        }

        update tickets;

        Set<Id> eventIds = new Set<Id>();
        for (Ticket__c t : tickets) {
            eventIds.add(t.Sport_Event__c);
        }

        if (!eventIds.isEmpty()) {
            TicketInventoryService.updateEventAvailabilityStatus(eventIds);
        }
    }

    /**
     * @param eventIds Set из ID новых Sport_Event__c
     */
    public static void reserveSeasonPassSeatsForNewEvents(Set<Id> eventIds) {
        if (eventIds == null || eventIds.isEmpty()) return;

        List<Sport_Event__c> newEvents = [
            SELECT Id, Home_Team__c, Season__c, Date_Time__c
            FROM Sport_Event__c
            WHERE Id IN :eventIds
        ];

        Set<String> teamSeasonKeys = new Set<String>();
        Map<String, Id> teamSeasonToTeam = new Map<String, Id>();
        Map<String, String> teamSeasonToSeason = new Map<String, String>();

        for (Sport_Event__c evt : newEvents) {
            String key = evt.Home_Team__c + '-' + evt.Season__c;
            teamSeasonKeys.add(key);
            teamSeasonToTeam.put(key, evt.Home_Team__c);
            teamSeasonToSeason.put(key, evt.Season__c);
        }

        List<Season_Pass__c> activePasses = [
            SELECT Id, Team__c, Season__c, Stadium_Section__c, Preferred_Row__c, Preferred_Seats__c, Start_Date__c, End_Date__c
            FROM Season_Pass__c
            WHERE Team__c IN :teamSeasonToTeam.values()
              AND Season__c IN :teamSeasonToSeason.values()
              AND Status__c = 'Active'
        ];

        if (activePasses.isEmpty()) return;

        Map<String, List<Season_Pass__c>> passesByTeamSeason = new Map<String, List<Season_Pass__c>>();
        for (Season_Pass__c sp : activePasses) {
            String key = sp.Team__c + '-' + sp.Season__c;
            if (!passesByTeamSeason.containsKey(key)) {
                passesByTeamSeason.put(key, new List<Season_Pass__c>());
            }
            passesByTeamSeason.get(key).add(sp);
        }

        Set<Id> affectedEventIds = new Set<Id>();
        for (Sport_Event__c evt : newEvents) {
            String key = evt.Home_Team__c + '-' + evt.Season__c;
            List<Season_Pass__c> passes = passesByTeamSeason.get(key);
            if (passes != null) {
                for (Season_Pass__c sp : passes) {
                    if (evt.Date_Time__c >= sp.Start_Date__c && evt.Date_Time__c <= sp.End_Date__c) {
                        try {
                            reserveSeatsForEvent(sp, evt.Id);
                            affectedEventIds.add(evt.Id);
                        } catch (Exception ex) {
                            System.debug('Failed to reserve seats for Season Pass ' + sp.Id + ': ' + ex.getMessage());
                        }
                    }
                }
            }
        }

        if (!affectedEventIds.isEmpty()) {
            TicketInventoryService.updateEventAvailabilityStatus(affectedEventIds);
        }
    }

    private static void reserveSeatsForEvents(Season_Pass__c sp, Set<Id> eventIds) {
        for (Id evtId : eventIds) {
            reserveSeatsForEvent(sp, evtId);
        }
        TicketInventoryService.updateEventAvailabilityStatus(eventIds);
    }

    private static void reserveSeatsForEvent(Season_Pass__c sp, Id eventId) {
        Sport_Event__c evt = [SELECT Id, Date_Time__c FROM Sport_Event__c WHERE Id = :eventId];
        
        Integer seatsNeeded = 1;
        if (sp.Preferred_Seats__c != null) {
            try {
                seatsNeeded = Integer.valueOf(sp.Preferred_Seats__c);
            } catch (TypeException e) {
                throw new SeasonPassException('Поле Preferred_Seats__c должно содержать целое число');
            }
        }

        String query = 'SELECT Id FROM Ticket__c WHERE Sport_Event__c = :eventId AND Stadium_Section__c = :sp.Stadium_Section__c AND Status__c = \'Available\'';
        if (sp.Preferred_Row__c != null) {
            Integer preferredRow;
            try {
                preferredRow = Integer.valueOf(sp.Preferred_Row__c);
            } catch (TypeException e) {
                throw new SeasonPassException('Поле Preferred_Row__c должно содержать целое число');
            }
            query += ' AND Row_Number__c = :preferredRow';
        }
        query += ' ORDER BY Row_Number__c, Seat_Number__c LIMIT :seatsNeeded FOR UPDATE';

        List<Ticket__c> tickets = Database.query(query);

        if (tickets.size() < seatsNeeded) {
            if (sp.Preferred_Row__c != null) {
                query = 'SELECT Id FROM Ticket__c WHERE Sport_Event__c = :eventId AND Stadium_Section__c = :sp.Stadium_Section__c AND Status__c = \'Available\' ORDER BY Row_Number__c, Seat_Number__c LIMIT :seatsNeeded FOR UPDATE';
                tickets = Database.query(query);
            }
        }

        if (tickets.size() < seatsNeeded) {
            throw new SeasonPassException('Недостаточно свободных мест в секции ' + sp.Stadium_Section__c);
        }

        for (Ticket__c t : tickets) {
            t.Status__c = 'Reserved';
            t.Is_Season_Pass_Ticket__c = true;
            t.Season_Pass__c = sp.Id;
            t.Reserved_Until__c = evt.Date_Time__c;
        }
        update tickets;
    }

    public class SeasonPassException extends Exception {}
}