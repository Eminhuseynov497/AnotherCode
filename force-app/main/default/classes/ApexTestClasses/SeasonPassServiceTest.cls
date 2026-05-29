@isTest
public class SeasonPassServiceTest {
    
    @isTest
    static void testCalculateSeasonPassPrice() {
        Stadium__c stadium = TestDataFactory.createStadium('Test Stadium');
        Stadium_Section__c section = TestDataFactory.createSection(stadium.Id, 'Section A', 10, 10, 50, 'Standard');
        League__c league = TestDataFactory.createLeague('Test League', 'USA', '2025', null);
        Team__c team = TestDataFactory.createTeam('Home', league.Id, stadium.Id);
        List<Sport_Event__c> events = new List<Sport_Event__c>();
        for (Integer i = 0; i < 10; i++) {
            events.add(TestDataFactory.createEvent(stadium.Id, team.Id, team.Id, league.Id, 
                                                   '2025', System.now().addDays(30 + i*10), 'Regular Season', 
                                                   1.0, 'On Sale'));
        }
        
        Decimal price = SeasonPassService.calculateSeasonPassPrice(team.Id, section.Id, '2025', 'Full');
        System.assertEquals(500.0, price);
    }
    
    @isTest
    static void testReserveFutureSeasonPassSeats() {
        Stadium__c stadium = TestDataFactory.createStadium('Test Stadium');
        Stadium_Section__c section = TestDataFactory.createSection(stadium.Id, 'Section A', 10, 10, 50, 'Standard');
        League__c league = TestDataFactory.createLeague('Test League', 'USA', '2025', null);
        Team__c team = TestDataFactory.createTeam('Home', league.Id, stadium.Id);
        Sport_Event__c event1 = TestDataFactory.createEvent(stadium.Id, team.Id, team.Id, league.Id, 
                                                            '2025', System.now().addDays(30), 'Regular Season', 
                                                            1.0, 'On Sale');
        Sport_Event__c event2 = TestDataFactory.createEvent(stadium.Id, team.Id, team.Id, league.Id, 
                                                            '2025', System.now().addDays(60), 'Regular Season', 
                                                            1.0, 'On Sale');
        Fan__c fan = TestDataFactory.createFan('fan@test.com', 'John', 'Doe', 'Bronze', 0, 0);
        Season_Pass__c pass = TestDataFactory.createSeasonPass(fan.Id, team.Id, section.Id, '2025',
                                                               Date.today(), Date.today().addMonths(6),
                                                               'Active', 500, 'Full');
        pass.Preferred_Row__c = 5;
        pass.Preferred_Seats__c = '1-2';
        update pass;
        
        TestDataFactory.generateTicketsForEvent(event1.Id, section.Id, 10, 10, 50);
        TestDataFactory.generateTicketsForEvent(event2.Id, section.Id, 10, 10, 50);
        
        Test.startTest();
        SeasonPassService.reserveFutureSeasonPassSeats(pass.Id);
        Test.stopTest();
        
        List<Ticket__c> reserved = [SELECT Id, Status__c, Season_Pass__c FROM Ticket__c 
                                     WHERE Sport_Event__c IN (:event1.Id, :event2.Id)
                                     AND Season_Pass__c = :pass.Id];
        System.assertEquals(4, reserved.size());
        for (Ticket__c t : reserved) {
            System.assertEquals('Reserved', t.Status__c);
        }
    }
    
    @isTest
    static void testReleaseFutureSeasonPassSeats() {
        Stadium__c stadium = TestDataFactory.createStadium('Test Stadium');
        Stadium_Section__c section = TestDataFactory.createSection(stadium.Id, 'Section A', 10, 10, 50, 'Standard');
        League__c league = TestDataFactory.createLeague('Test League', 'USA', '2025', null);
        Team__c team = TestDataFactory.createTeam('Home', league.Id, stadium.Id);
        Sport_Event__c event = TestDataFactory.createEvent(stadium.Id, team.Id, team.Id, league.Id, 
                                                           '2025', System.now().addDays(30), 'Regular Season', 
                                                           1.0, 'On Sale');
        Fan__c fan = TestDataFactory.createFan('fan@test.com', 'John', 'Doe', 'Bronze', 0, 0);
        Season_Pass__c pass = TestDataFactory.createSeasonPass(fan.Id, team.Id, section.Id, '2025',
                                                               Date.today(), Date.today().addMonths(6),
                                                               'Active', 500, 'Full');
        List<Ticket__c> tickets = TestDataFactory.generateTicketsForEvent(event.Id, section.Id, 10, 10, 50);
        for (Ticket__c t : tickets) {
            t.Season_Pass__c = pass.Id;
            t.Status__c = 'Reserved';
        }
        update tickets;
        
        Test.startTest();
        SeasonPassService.releaseFutureSeasonPassSeats(pass.Id);
        Test.stopTest();
        
        List<Ticket__c> released = [SELECT Id, Status__c, Season_Pass__c FROM Ticket__c WHERE Season_Pass__c = :pass.Id];
        for (Ticket__c t : released) {
            System.assertEquals('Available', t.Status__c);
            System.assertEquals(null, t.Season_Pass__c);
        }
    }
    
    @isTest
    static void testReserveSeasonPassSeatsForNewEvents() {
        Stadium__c stadium = TestDataFactory.createStadium('Test Stadium');
        Stadium_Section__c section = TestDataFactory.createSection(stadium.Id, 'Section A', 10, 10, 50, 'Standard');
        League__c league = TestDataFactory.createLeague('Test League', 'USA', '2025', null);
        Team__c team = TestDataFactory.createTeam('Home', league.Id, stadium.Id);
        Fan__c fan = TestDataFactory.createFan('fan@test.com', 'John', 'Doe', 'Bronze', 0, 0);
        Season_Pass__c pass = TestDataFactory.createSeasonPass(fan.Id, team.Id, section.Id, '2025',
                                                               Date.today(), Date.today().addMonths(6),
                                                               'Active', 500, 'Full');
        Sport_Event__c newEvent = TestDataFactory.createEvent(stadium.Id, team.Id, team.Id, league.Id, 
                                                              '2025', System.now().addDays(40), 'Regular Season', 
                                                              1.0, 'On Sale');
        TestDataFactory.generateTicketsForEvent(newEvent.Id, section.Id, 10, 10, 50);
        
        Test.startTest();
        SeasonPassService.reserveSeasonPassSeatsForNewEvents(new Set<Id>{newEvent.Id});
        Test.stopTest();
        
        List<Ticket__c> reserved = [SELECT Id, Status__c, Season_Pass__c FROM Ticket__c 
                                     WHERE Sport_Event__c = :newEvent.Id AND Season_Pass__c = :pass.Id];
        System.assertEquals(2, reserved.size());
        for (Ticket__c t : reserved) {
            System.assertEquals('Reserved', t.Status__c);
        }
    }
}