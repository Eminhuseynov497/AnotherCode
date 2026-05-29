@isTest
public class TriggerHandlerTests {
    
    @isTest
    static void testSportEventTrigger() {
        Stadium__c stadium = TestDataFactory.createStadium('Test Stadium');
        Stadium_Section__c section = TestDataFactory.createSection(stadium.Id, 'Section A', 2, 2, 50, 'Standard');
        League__c league = TestDataFactory.createLeague('Test League', 'USA', '2025', null);
        Team__c home = TestDataFactory.createTeam('Home', league.Id, stadium.Id);
        Team__c away = TestDataFactory.createTeam('Away', league.Id, stadium.Id);
        
        Sport_Event__c event = TestDataFactory.createEvent(stadium.Id, home.Id, away.Id, league.Id, 
                                                           '2025', System.now().addDays(10), 'Regular Season', 
                                                           1.0, 'Scheduled');
        List<Ticket__c> tickets = [SELECT Id FROM Ticket__c WHERE Sport_Event__c = :event.Id];
        System.assertEquals(0, tickets.size());
        
        event.Status__c = 'On Sale';
        update event;
        tickets = [SELECT Id FROM Ticket__c WHERE Sport_Event__c = :event.Id];
        System.assertEquals(4, tickets.size());
        
        event.Event_Type__c = 'Final';
        event.Price_Multiplier__c = 2.5;
        update event;
        List<Ticket__c> updatedTickets = [SELECT Id, Dynamic_Price__c FROM Ticket__c WHERE Sport_Event__c = :event.Id];
        for (Ticket__c t : updatedTickets) {
            System.assertEquals(125.0, t.Dynamic_Price__c);
        }
    }
    
    @isTest
    static void testTicketTrigger() {
        Stadium__c stadium = TestDataFactory.createStadium('Test Stadium');
        Stadium_Section__c section = TestDataFactory.createSection(stadium.Id, 'Section A', 2, 2, 50, 'Standard');
        League__c league = TestDataFactory.createLeague('Test League', 'USA', '2025', null);
        Team__c home = TestDataFactory.createTeam('Home', league.Id, stadium.Id);
        Team__c away = TestDataFactory.createTeam('Away', league.Id, stadium.Id);
        Sport_Event__c event = TestDataFactory.createEvent(stadium.Id, home.Id, away.Id, league.Id, 
                                                           '2025', System.now().addDays(10), 'Regular Season', 
                                                           1.0, 'On Sale');
        Ticket__c ticket = new Ticket__c(
            Sport_Event__c = event.Id,
            Stadium_Section__c = section.Id,
            Row_Number__c = 1,
            Seat_Number__c = 1,
            Status__c = 'Available',
            Base_Price__c = 50
        );
        insert ticket;
        
        Ticket__c inserted = [SELECT Id, QR_Code__c, Seat_Key__c FROM Ticket__c WHERE Id = :ticket.Id];
        System.assertNotEquals(null, inserted.QR_Code__c);
        System.assertNotEquals(null, inserted.Seat_Key__c);
        
        ticket.Status__c = 'Checked In';
        try {
            update ticket;
            System.assert(false, 'Should not allow Checked In without Checked_In_At__c');
        } catch (Exception e) {
            System.assert(true);
        }
        
        ticket.Checked_In_At__c = System.now();
        update ticket;
        Ticket__c checkedIn = [SELECT Id, Status__c, Checked_In_At__c FROM Ticket__c WHERE Id = :ticket.Id];
        System.assertEquals('Checked In', checkedIn.Status__c);
        System.assertNotEquals(null, checkedIn.Checked_In_At__c);
    }
    
    @isTest
    static void testPurchaseOrderTrigger() {
        Stadium__c stadium = TestDataFactory.createStadium('Test Stadium');
        Stadium_Section__c section = TestDataFactory.createSection(stadium.Id, 'Section A', 2, 2, 50, 'Standard');
        League__c league = TestDataFactory.createLeague('Test League', 'USA', '2025', null);
        Team__c home = TestDataFactory.createTeam('Home', league.Id, stadium.Id);
        Team__c away = TestDataFactory.createTeam('Away', league.Id, stadium.Id);
        Sport_Event__c event = TestDataFactory.createEvent(stadium.Id, home.Id, away.Id, league.Id, 
                                                           '2025', System.now().addDays(10), 'Regular Season', 
                                                           1.0, 'On Sale');
        Fan__c fan = TestDataFactory.createFan('fan@test.com', 'John', 'Doe', 'Bronze', 0, 0);
        Purchase_Order__c order = TestDataFactory.createOrder(fan.Id, event.Id, 'Pending', 100, 0, 0);
        
        System.assertNotEquals(null, order.Order_Number__c);
        
        order.Status__c = 'Confirmed';
        update order;
        
        Fan__c updatedFan = [SELECT Id, Loyalty_Points_Balance__c FROM Fan__c WHERE Id = :fan.Id];
        System.assertEquals(100, updatedFan.Loyalty_Points_Balance__c);
        
        order.Status__c = 'Cancelled';
        update order;
        updatedFan = [SELECT Id, Loyalty_Points_Balance__c FROM Fan__c WHERE Id = :fan.Id];
        System.assertEquals(0, updatedFan.Loyalty_Points_Balance__c);
    }
    
    @isTest
    static void testFanTrigger() {
        Fan__c fan = new Fan__c(
            First_Name__c = 'Test',
            Last_Name__c = 'Fan',
            Email__c = ' TEST@EXAMPLE.COM ',
            Phone__c = '1234567890',
            Date_of_Birth__c = Date.newInstance(1990, 1, 1),
            City__c = 'Test City',
            Registration_Date__c = Date.today(),
            Loyalty_Tier__c = 'Bronze',
            Loyalty_Points_Balance__c = 0,
            Lifetime_Points__c = 0
        );
        insert fan;
        
        Fan__c inserted = [SELECT Id, Email__c FROM Fan__c WHERE Id = :fan.Id];
        System.assertEquals('test@example.com', inserted.Email__c); // normalized to lowercase
    }
    
    @isTest
    static void testSeasonPassTrigger() {
        Stadium__c stadium = TestDataFactory.createStadium('Test Stadium');
        Stadium_Section__c section = TestDataFactory.createSection(stadium.Id, 'Section A', 10, 10, 50, 'Standard');
        League__c league = TestDataFactory.createLeague('Test League', 'USA', '2025', null);
        Team__c team = TestDataFactory.createTeam('Home', league.Id, stadium.Id);
        Fan__c fan = TestDataFactory.createFan('fan@test.com', 'John', 'Doe', 'Bronze', 0, 0);
        Sport_Event__c event = TestDataFactory.createEvent(stadium.Id, team.Id, team.Id, league.Id, 
                                                           '2025', System.now().addDays(30), 'Regular Season', 
                                                           1.0, 'On Sale');
        TestDataFactory.generateTicketsForEvent(event.Id, section.Id, 10, 10, 50);
        
        Season_Pass__c pass = new Season_Pass__c(
            Fan__c = fan.Id,
            Team__c = team.Id,
            Stadium_Section__c = section.Id,
            Season__c = '2025',
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addMonths(6),
            Status__c = 'Active',
            Season_Pass_Price__c = 500,
            Payment_Plan__c = 'Full',
            Auto_Renew__c = true,
            Preferred_Row__c = 5,
            Preferred_Seats__c = '1-2'
        );
        insert pass;
        
        List<Ticket__c> reserved = [SELECT Id, Status__c, Season_Pass__c FROM Ticket__c 
                                     WHERE Sport_Event__c = :event.Id AND Season_Pass__c = :pass.Id];
        System.assertEquals(2, reserved.size());
        for (Ticket__c t : reserved) {
            System.assertEquals('Reserved', t.Status__c);
        }
        
        pass.Status__c = 'Cancelled';
        update pass;
        
        List<Ticket__c> released = [SELECT Id, Status__c, Season_Pass__c FROM Ticket__c 
                                     WHERE Sport_Event__c = :event.Id AND Season_Pass__c = :pass.Id];
        System.assertEquals(0, released.size());
    }
}