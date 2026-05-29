@isTest
public class TicketInventoryServiceTest {
    
    @isTest
    static void testGenerateTickets() {
        Stadium__c stadium = TestDataFactory.createStadium('Test Stadium');
        Stadium_Section__c section = TestDataFactory.createSection(stadium.Id, 'Section A', 3, 3, 50, 'Standard');
        League__c league = TestDataFactory.createLeague('Test League', 'USA', '2025', null);
        Team__c home = TestDataFactory.createTeam('Home', league.Id, stadium.Id);
        Team__c away = TestDataFactory.createTeam('Away', league.Id, stadium.Id);
        Sport_Event__c event = TestDataFactory.createEvent(stadium.Id, home.Id, away.Id, league.Id, 
                                                           '2025', System.now().addDays(10), 'Regular Season', 
                                                           1.0, 'Scheduled');
        
        Test.startTest();
        TicketInventoryService.generateTickets(new Set<Id>{event.Id});
        Test.stopTest();
        
        List<Ticket__c> tickets = [SELECT Id FROM Ticket__c WHERE Sport_Event__c = :event.Id];
        System.assertEquals(9, tickets.size());
    }
    
    @isTest
    static void testReserveAndConfirmTickets() {
        Stadium__c stadium = TestDataFactory.createStadium('Test Stadium');
        Stadium_Section__c section = TestDataFactory.createSection(stadium.Id, 'Section A', 2, 2, 50, 'Standard');
        League__c league = TestDataFactory.createLeague('Test League', 'USA', '2025', null);
        Team__c home = TestDataFactory.createTeam('Home', league.Id, stadium.Id);
        Team__c away = TestDataFactory.createTeam('Away', league.Id, stadium.Id);
        Sport_Event__c event = TestDataFactory.createEvent(stadium.Id, home.Id, away.Id, league.Id, 
                                                           '2025', System.now().addDays(10), 'Regular Season', 
                                                           1.0, 'On Sale');
        List<Ticket__c> tickets = TestDataFactory.generateTicketsForEvent(event.Id, section.Id, 2, 2, 50);
        Set<Id> ticketIds = new Set<Id>();
        for (Ticket__c t : tickets) {
            ticketIds.add(t.Id);
        }
        Fan__c fan = TestDataFactory.createFan('fan@test.com', 'John', 'Doe', 'Silver', 100, 100);
        Purchase_Order__c order = TestDataFactory.createOrder(fan.Id, event.Id, 'Pending', 100, 0, 0);
        
        Test.startTest();
        TicketInventoryService.reserveTickets(ticketIds, System.now().addMinutes(15));
        List<Ticket__c> reserved = [SELECT Id, Status__c, Reserved_Until__c FROM Ticket__c WHERE Id IN :ticketIds];
        for (Ticket__c t : reserved) {
            System.assertEquals('Reserved', t.Status__c);
            System.assertNotEquals(null, t.Reserved_Until__c);
        }
        
        TicketInventoryService.confirmReservedTickets(order.Id, ticketIds);
        Test.stopTest();
        
        List<Ticket__c> sold = [SELECT Id, Status__c, Purchase_Order__c FROM Ticket__c WHERE Id IN :ticketIds];
        for (Ticket__c t : sold) {
            System.assertEquals('Sold', t.Status__c);
            System.assertEquals(order.Id, t.Purchase_Order__c);
        }
    }
    
    @isTest
    static void testReleaseExpiredReservations() {
        Stadium__c stadium = TestDataFactory.createStadium('Test Stadium');
        Stadium_Section__c section = TestDataFactory.createSection(stadium.Id, 'Section A', 1, 1, 50, 'Standard');
        League__c league = TestDataFactory.createLeague('Test League', 'USA', '2025', null);
        Team__c home = TestDataFactory.createTeam('Home', league.Id, stadium.Id);
        Team__c away = TestDataFactory.createTeam('Away', league.Id, stadium.Id);
        Sport_Event__c event = TestDataFactory.createEvent(stadium.Id, home.Id, away.Id, league.Id, 
                                                           '2025', System.now().addDays(10), 'Regular Season', 
                                                           1.0, 'On Sale');
        Ticket__c ticket = TestDataFactory.createTicket(event.Id, section.Id, 1, 1, 'Reserved', 50);
        ticket.Reserved_Until__c = System.now().addMinutes(-5);
        update ticket;
        
        Test.startTest();
        TicketInventoryService.releaseExpiredReservations();
        Test.stopTest();
        
        Ticket__c released = [SELECT Id, Status__c, Reserved_Until__c FROM Ticket__c WHERE Id = :ticket.Id];
        System.assertEquals('Available', released.Status__c);
        System.assertEquals(null, released.Reserved_Until__c);
    }
    
    @isTest
    static void testUpdateEventAvailabilityStatus() {
        Stadium__c stadium = TestDataFactory.createStadium('Test Stadium');
        Stadium_Section__c section = TestDataFactory.createSection(stadium.Id, 'Section A', 2, 2, 50, 'Standard');
        League__c league = TestDataFactory.createLeague('Test League', 'USA', '2025', null);
        Team__c home = TestDataFactory.createTeam('Home', league.Id, stadium.Id);
        Team__c away = TestDataFactory.createTeam('Away', league.Id, stadium.Id);
        Sport_Event__c event = TestDataFactory.createEvent(stadium.Id, home.Id, away.Id, league.Id, 
                                                           '2025', System.now().addDays(10), 'Regular Season', 
                                                           1.0, 'On Sale');
        TestDataFactory.generateTicketsForEvent(event.Id, section.Id, 2, 2, 50);
        
        List<Ticket__c> tickets = [SELECT Id FROM Ticket__c WHERE Sport_Event__c = :event.Id];
        for (Ticket__c t : tickets) {
            t.Status__c = 'Sold';
        }
        update tickets;
        
        Test.startTest();
        TicketInventoryService.updateEventAvailabilityStatus(new Set<Id>{event.Id});
        Test.stopTest();
        
        Sport_Event__c updated = [SELECT Id, Status__c FROM Sport_Event__c WHERE Id = :event.Id];
        System.assertEquals('Sold Out', updated.Status__c);
    }
}