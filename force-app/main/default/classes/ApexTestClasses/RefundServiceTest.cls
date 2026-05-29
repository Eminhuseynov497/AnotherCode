@isTest
public class RefundServiceTest {
    
    @isTest
    static void testCancelOrder() {
        Stadium__c stadium = TestDataFactory.createStadium('Test Stadium');
        Stadium_Section__c section = TestDataFactory.createSection(stadium.Id, 'Section A', 2, 2, 50, 'Standard');
        League__c league = TestDataFactory.createLeague('Test League', 'USA', '2025', null);
        Team__c home = TestDataFactory.createTeam('Home', league.Id, stadium.Id);
        Team__c away = TestDataFactory.createTeam('Away', league.Id, stadium.Id);
        Sport_Event__c event = TestDataFactory.createEvent(stadium.Id, home.Id, away.Id, league.Id, 
                                                           '2025', System.now().addDays(10), 'Regular Season', 
                                                           1.0, 'On Sale');
        Fan__c fan = TestDataFactory.createFan('fan@test.com', 'John', 'Doe', 'Silver', 100, 100);
        Purchase_Order__c order = TestDataFactory.createOrder(fan.Id, event.Id, 'Confirmed', 100, 0, 0);
        Ticket__c ticket = TestDataFactory.createTicket(event.Id, section.Id, 1, 1, 'Sold', 50);
        ticket.Purchase_Order__c = order.Id;
        update ticket;
        
        Test.startTest();
        RefundService.cancelOrder(order.Id);
        Test.stopTest();
        
        Purchase_Order__c cancelled = [SELECT Id, Status__c FROM Purchase_Order__c WHERE Id = :order.Id];
        System.assertEquals('Cancelled', cancelled.Status__c);
        
        Ticket__c released = [SELECT Id, Status__c FROM Ticket__c WHERE Id = :ticket.Id];
        System.assertEquals('Available', released.Status__c);
    }
    
    @isTest
    static void testProcessEventCancellation() {
        Stadium__c stadium = TestDataFactory.createStadium('Test Stadium');
        Stadium_Section__c section = TestDataFactory.createSection(stadium.Id, 'Section A', 2, 2, 50, 'Standard');
        League__c league = TestDataFactory.createLeague('Test League', 'USA', '2025', null);
        Team__c home = TestDataFactory.createTeam('Home', league.Id, stadium.Id);
        Team__c away = TestDataFactory.createTeam('Away', league.Id, stadium.Id);
        Sport_Event__c event = TestDataFactory.createEvent(stadium.Id, home.Id, away.Id, league.Id, 
                                                           '2025', System.now().addDays(10), 'Regular Season', 
                                                           1.0, 'On Sale');
        Fan__c fan = TestDataFactory.createFan('fan@test.com', 'John', 'Doe', 'Silver', 100, 100);
        Purchase_Order__c order = TestDataFactory.createOrder(fan.Id, event.Id, 'Confirmed', 100, 0, 0);
        Ticket__c ticket = TestDataFactory.createTicket(event.Id, section.Id, 1, 1, 'Sold', 50);
        ticket.Purchase_Order__c = order.Id;
        update ticket;
        
        Test.startTest();
        RefundService.processEventCancellation(event.Id);
        Test.stopTest();
        
        Purchase_Order__c refunded = [SELECT Id, Status__c FROM Purchase_Order__c WHERE Id = :order.Id];
        System.assertEquals('Refunded', refunded.Status__c);
    }
    
    @isTest
    static void testRestoreRedeemedPoints() {
        Fan__c fan = TestDataFactory.createFan('fan@test.com', 'John', 'Doe', 'Silver', 300, 500);
        Stadium__c stadium = TestDataFactory.createStadium('Test Stadium');
        League__c league = TestDataFactory.createLeague('Test League', 'USA', '2025', null);
        Team__c home = TestDataFactory.createTeam('Home', league.Id, stadium.Id);
        Team__c away = TestDataFactory.createTeam('Away', league.Id, stadium.Id);
        Sport_Event__c event = TestDataFactory.createEvent(stadium.Id, home.Id, away.Id, league.Id, 
                                                           '2025', System.now().addDays(10), 'Regular Season', 
                                                           1.0, 'On Sale');
        Purchase_Order__c order = TestDataFactory.createOrder(fan.Id, event.Id, 'Confirmed', 100, 0, 100);
        
        Test.startTest();
        RefundService.restoreRedeemedPoints(order.Id);
        Test.stopTest();
        
        Fan__c updated = [SELECT Id, Loyalty_Points_Balance__c FROM Fan__c WHERE Id = :fan.Id];
        System.assertEquals(400, updated.Loyalty_Points_Balance__c);
    }
}