@isTest
public class DynamicPricingServiceTest {
    
    @isTest
    static void testCalculateTicketPrice() {
        Stadium__c stadium = TestDataFactory.createStadium('Test Stadium');
        Stadium_Section__c section = TestDataFactory.createSection(stadium.Id, 'Section A', 10, 10, 100, 'Standard');
        League__c league = TestDataFactory.createLeague('Test League', 'USA', '2025', null);
        Team__c home = TestDataFactory.createTeam('Home', league.Id, stadium.Id);
        Team__c away = TestDataFactory.createTeam('Away', league.Id, stadium.Id);
        Sport_Event__c event = TestDataFactory.createEvent(stadium.Id, home.Id, away.Id, league.Id, 
                                                           '2025', System.now().addDays(10), 'Regular Season', 
                                                           1.0, 'On Sale');
        Ticket__c ticket = TestDataFactory.createTicket(event.Id, section.Id, 1, 1, 'Available', 100);
        
        Decimal soldPercent = 30;
        Decimal result = DynamicPricingService.calculateTicketPrice(ticket, event, soldPercent);
        System.assertEquals(100.0, result, 'Price should be base 100 with all factors 1.0');
        
        event.Price_Multiplier__c = 2.5;
        soldPercent = 90;
        result = DynamicPricingService.calculateTicketPrice(ticket, event, soldPercent);
        System.assertEquals(337.5, result);
    }
    
    @isTest
    static void testRecalculateEventPrices() {
        Stadium__c stadium = TestDataFactory.createStadium('Test Stadium');
        Stadium_Section__c section = TestDataFactory.createSection(stadium.Id, 'Section A', 5, 5, 100, 'Standard');
        League__c league = TestDataFactory.createLeague('Test League', 'USA', '2025', null);
        Team__c home = TestDataFactory.createTeam('Home', league.Id, stadium.Id);
        Team__c away = TestDataFactory.createTeam('Away', league.Id, stadium.Id);
        Sport_Event__c event = TestDataFactory.createEvent(stadium.Id, home.Id, away.Id, league.Id, 
                                                           '2025', System.now().addDays(5), 'Playoff', 
                                                           1.7, 'On Sale');
        List<Ticket__c> tickets = TestDataFactory.generateTicketsForEvent(event.Id, section.Id, 5, 5, 100);
        
        List<Ticket__c> toSell = new List<Ticket__c>();
        for (Integer i = 0; i < 20; i++) {
            tickets[i].Status__c = 'Sold';
            toSell.add(tickets[i]);
        }
        update toSell;
        
        Test.startTest();
        DynamicPricingService.recalculateEventPrices(new Set<Id>{event.Id});
        Test.stopTest();
        
        List<Ticket__c> updated = [SELECT Id, Dynamic_Price__c FROM Ticket__c WHERE Sport_Event__c = :event.Id];
        for (Ticket__c t : updated) {
            System.assertEquals(224.40, t.Dynamic_Price__c);
        }
    }
    
    @isTest
    static void testGetLoyaltyDiscountPercent() {
        Fan__c fan = TestDataFactory.createFan('test@example.com', 'Test', 'Fan', 'Platinum', 0, 5000);
        Decimal discount = DynamicPricingService.getLoyaltyDiscountPercent(fan.Id);
        System.assertEquals(15, discount);
        
        fan.Loyalty_Tier__c = 'Gold';
        update fan;
        discount = DynamicPricingService.getLoyaltyDiscountPercent(fan.Id);
        System.assertEquals(10, discount);
        
        fan.Loyalty_Tier__c = 'Silver';
        update fan;
        discount = DynamicPricingService.getLoyaltyDiscountPercent(fan.Id);
        System.assertEquals(5, discount);
        
        fan.Loyalty_Tier__c = 'Bronze';
        update fan;
        discount = DynamicPricingService.getLoyaltyDiscountPercent(fan.Id);
        System.assertEquals(0, discount);
    }
    
    @isTest
    static void testGetEventPriceSummary() {
        Stadium__c stadium = TestDataFactory.createStadium('Test Stadium');
        Stadium_Section__c section = TestDataFactory.createSection(stadium.Id, 'Section A', 5, 5, 100, 'Standard');
        League__c league = TestDataFactory.createLeague('Test League', 'USA', '2025', null);
        Team__c home = TestDataFactory.createTeam('Home', league.Id, stadium.Id);
        Team__c away = TestDataFactory.createTeam('Away', league.Id, stadium.Id);
        Sport_Event__c event = TestDataFactory.createEvent(stadium.Id, home.Id, away.Id, league.Id, 
                                                           '2025', System.now().addDays(10), 'Regular Season', 
                                                           1.0, 'On Sale');
        TestDataFactory.generateTicketsForEvent(event.Id, section.Id, 5, 5, 100);
        
        Map<String, Decimal> summary = DynamicPricingService.getEventPriceSummary(event.Id);
        System.assertEquals(100.0, summary.get('minPrice'));
        System.assertEquals(100.0, summary.get('maxPrice'));
        System.assertEquals(100.0, summary.get('avgPrice'));
    }
}