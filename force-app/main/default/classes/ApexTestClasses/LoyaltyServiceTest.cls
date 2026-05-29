@isTest
public class LoyaltyServiceTest {
    
    @isTest
    static void testAwardPurchasePoints() {
        Stadium__c stadium = TestDataFactory.createStadium('Test Stadium');
        Stadium_Section__c section = TestDataFactory.createSection(stadium.Id, 'Section A', 2, 2, 50, 'Standard');
        League__c league = TestDataFactory.createLeague('Test League', 'USA', '2025', null);
        Team__c home = TestDataFactory.createTeam('Home', league.Id, stadium.Id);
        Team__c away = TestDataFactory.createTeam('Away', league.Id, stadium.Id);
        Sport_Event__c event = TestDataFactory.createEvent(stadium.Id, home.Id, away.Id, league.Id, 
                                                           '2025', System.now().addDays(10), 'Regular Season', 
                                                           1.0, 'On Sale');
        Fan__c fan = TestDataFactory.createFan('fan@test.com', 'John', 'Doe', 'Bronze', 0, 0);
        Purchase_Order__c order = TestDataFactory.createOrder(fan.Id, event.Id, 'Confirmed', 200, 0, 0);
        
        Test.startTest();
        LoyaltyService.awardPurchasePoints(order.Id);
        Test.stopTest();
        
        Fan__c updatedFan = [SELECT Id, Loyalty_Points_Balance__c, Lifetime_Points__c, Loyalty_Season__c FROM Fan__c WHERE Id = :fan.Id];
        System.assertEquals(200, updatedFan.Loyalty_Points_Balance__c);
        System.assertEquals(200, updatedFan.Lifetime_Points__c);
        System.assertEquals('2025', updatedFan.Loyalty_Season__c);
    }
    
    @isTest
    static void testRedeemPoints() {
        Fan__c fan = TestDataFactory.createFan('fan@test.com', 'John', 'Doe', 'Silver', 500, 500);
        Stadium__c stadium = TestDataFactory.createStadium('Test Stadium');
        League__c league = TestDataFactory.createLeague('Test League', 'USA', '2025', null);
        Team__c home = TestDataFactory.createTeam('Home', league.Id, stadium.Id);
        Team__c away = TestDataFactory.createTeam('Away', league.Id, stadium.Id);
        Sport_Event__c event = TestDataFactory.createEvent(stadium.Id, home.Id, away.Id, league.Id, 
                                                           '2025', System.now().addDays(10), 'Regular Season', 
                                                           1.0, 'On Sale');
        Purchase_Order__c order = TestDataFactory.createOrder(fan.Id, event.Id, 'Pending', 100, 0, 0);
        
        Test.startTest();
        LoyaltyService.redeemPoints(fan.Id, 200, order.Id);
        Test.stopTest();
        
        Fan__c updatedFan = [SELECT Id, Loyalty_Points_Balance__c, Lifetime_Points__c FROM Fan__c WHERE Id = :fan.Id];
        System.assertEquals(300, updatedFan.Loyalty_Points_Balance__c);
        System.assertEquals(500, updatedFan.Lifetime_Points__c);
    }
    
    @isTest
    static void testAwardAttendancePoints() {
        Stadium__c stadium = TestDataFactory.createStadium('Test Stadium');
        Stadium_Section__c section = TestDataFactory.createSection(stadium.Id, 'Section A', 2, 2, 50, 'Standard');
        League__c league = TestDataFactory.createLeague('Test League', 'USA', '2025', null);
        Team__c home = TestDataFactory.createTeam('Home', league.Id, stadium.Id);
        Team__c away = TestDataFactory.createTeam('Away', league.Id, stadium.Id);
        Sport_Event__c event = TestDataFactory.createEvent(stadium.Id, home.Id, away.Id, league.Id, 
                                                           '2025', System.now().addDays(-1), 'Regular Season', 
                                                           1.0, 'Completed');
        Fan__c fan = TestDataFactory.createFan('fan@test.com', 'John', 'Doe', 'Bronze', 0, 0);
        Purchase_Order__c order = TestDataFactory.createOrder(fan.Id, event.Id, 'Confirmed', 100, 0, 0);
        Ticket__c ticket = TestDataFactory.createTicket(event.Id, section.Id, 1, 1, 'Checked In', 50);
        ticket.Purchase_Order__c = order.Id;
        update ticket;
        
        Test.startTest();
        LoyaltyService.awardAttendancePoints(event.Id);
        Test.stopTest();
        
        Fan__c updatedFan = [SELECT Id, Loyalty_Points_Balance__c, Lifetime_Points__c FROM Fan__c WHERE Id = :fan.Id];
        System.assertEquals(50, updatedFan.Loyalty_Points_Balance__c);
        System.assertEquals(50, updatedFan.Lifetime_Points__c);
    }
    
    @isTest
    static void testEvaluateTier() {
        Fan__c fan = TestDataFactory.createFan('fan@test.com', 'John', 'Doe', 'Bronze', 0, 0);
        fan.Lifetime_Points__c = 3000;
        update fan;
        
        Test.startTest();
        LoyaltyService.evaluateTier(new Set<Id>{fan.Id});
        Test.stopTest();
        
        Fan__c updated = [SELECT Id, Loyalty_Tier__c FROM Fan__c WHERE Id = :fan.Id];
        System.assertEquals('Gold', updated.Loyalty_Tier__c);
    }
    
    @isTest
    static void testAwardBirthdayBonus() {
        Fan__c fan = TestDataFactory.createFan('fan@test.com', 'John', 'Doe', 'Bronze', 0, 0);
        fan.Date_of_Birth__c = Date.today();
        fan.Last_Birthday_Bonus_Date__c = null;
        update fan;
        
        Test.startTest();
        LoyaltyService.awardBirthdayBonus();
        Test.stopTest();
        
        Fan__c updated = [SELECT Id, Loyalty_Points_Balance__c, Lifetime_Points__c, Last_Birthday_Bonus_Date__c FROM Fan__c WHERE Id = :fan.Id];
        System.assertEquals(100, updated.Loyalty_Points_Balance__c);
        System.assertEquals(100, updated.Lifetime_Points__c);
        System.assertEquals(Date.today(), updated.Last_Birthday_Bonus_Date__c);
    }
}