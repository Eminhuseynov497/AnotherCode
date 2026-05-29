public with sharing class DynamicPricingService {
    public static Decimal calculateTicketPrice(Ticket__c ticket, Sport_Event__c event, Decimal sectionSoldPercent) {
        Decimal basePrice = ticket.Stadium_Section__r.Base_Price__c != null 
            ? ticket.Stadium_Section__r.Base_Price__c 
            : 0;
        
        Decimal eventMultiplier = event.Price_Multiplier__c != null 
            ? event.Price_Multiplier__c 
            : 1.00;
        
        Decimal demandFactor = getDemandFactor(sectionSoldPercent);
        
        Decimal timeFactor = getTimeFactor(event.Date_Time__c);
        
        Decimal dynamicPrice = basePrice * eventMultiplier * demandFactor * timeFactor;
        
        return dynamicPrice.setScale(2, RoundingMode.HALF_UP);
    }

    public static void recalculateEventPrices(Set<Id> eventIds) {
        List<Sport_Event__c> events = [
            SELECT Id, Date_Time__c, Price_Multiplier__c 
            FROM Sport_Event__c 
            WHERE Id IN :eventIds
        ];
        
        for (Sport_Event__c event : events) {
            Map<Id, Decimal> sectionSoldPercent = getSectionSoldPercent(event.Id);
            
            List<Ticket__c> tickets = [
                SELECT Id, Dynamic_Price__c, Stadium_Section__c,
                       Stadium_Section__r.Base_Price__c
                FROM Ticket__c
                WHERE Sport_Event__c = :event.Id
            ];
            
            for (Ticket__c ticket : tickets) {
                Decimal soldPercent = sectionSoldPercent.get(ticket.Stadium_Section__c) != null
                    ? sectionSoldPercent.get(ticket.Stadium_Section__c)
                    : 0;
                
                ticket.Dynamic_Price__c = calculateTicketPrice(ticket, event, soldPercent);
            }
            
            update tickets;
        }
    }

    public static void recalculateSectionPrices(Id eventId, Id sectionId) {
        Sport_Event__c event = [
            SELECT Id, Date_Time__c, Price_Multiplier__c 
            FROM Sport_Event__c 
            WHERE Id = :eventId
        ];
        
        Decimal soldPercent = getSectionSoldPercent(eventId).get(sectionId);
        
        List<Ticket__c> tickets = [
            SELECT Id, Dynamic_Price__c, Stadium_Section__c,
                   Stadium_Section__r.Base_Price__c
            FROM Ticket__c
            WHERE Sport_Event__c = :eventId 
              AND Stadium_Section__c = :sectionId
        ];
        
        for (Ticket__c ticket : tickets) {
            ticket.Dynamic_Price__c = calculateTicketPrice(ticket, event, soldPercent);
        }
        
        update tickets;
    }

    public static Map<String, Decimal> getEventPriceSummary(Id eventId) {
        AggregateResult[] results = [
            SELECT MIN(Dynamic_Price__c) minPrice,
                   MAX(Dynamic_Price__c) maxPrice,
                   AVG(Dynamic_Price__c) avgPrice
            FROM Ticket__c
            WHERE Sport_Event__c = :eventId 
              AND Status__c = 'Available'
        ];
        
        Map<String, Decimal> summary = new Map<String, Decimal>();
        if (!results.isEmpty()) {
            summary.put('minPrice', (Decimal)results[0].get('minPrice'));
            summary.put('maxPrice', (Decimal)results[0].get('maxPrice'));
            summary.put('avgPrice', (Decimal)results[0].get('avgPrice'));
        }
        return summary;
    }

    public static Decimal getLoyaltyDiscountPercent(Id fanId) {
        if (fanId == null) return 0;
        
        Fan__c fan = [SELECT Loyalty_Tier__c FROM Fan__c WHERE Id = :fanId LIMIT 1];
        
        String tier = fan.Loyalty_Tier__c;
        if (tier == 'Bronze')   return 0;
        if (tier == 'Silver')   return 5;
        if (tier == 'Gold')     return 10;
        if (tier == 'Platinum') return 15;
        return 0;
    }

    private static Decimal getDemandFactor(Decimal soldPercent) {
        if (soldPercent < 50) {
            return 1.00;
        } else if (soldPercent >= 50 && soldPercent < 70) {
            return 1.10;
        } else if (soldPercent >= 70 && soldPercent < 85) {
            return 1.20;
        } else { 
            return 1.35;
        }
    }

    private static Decimal getTimeFactor(Datetime eventDateTime) {
        Long timeRemaining = eventDateTime.getTime() - System.now().getTime();
        Long daysRemaining = timeRemaining / (1000 * 60 * 60 * 24);
        
        if (daysRemaining > 30) {
            return 0.95;
        } else if (daysRemaining >= 8) {
            return 1.00;
        } else if (daysRemaining >= 2) {
            return 1.10;
        } else { 
            return 1.25;
        }
    }

    private static Map<Id, Decimal> getSectionSoldPercent(Id eventId) {
        Map<Id, Decimal> result = new Map<Id, Decimal>();
        
        Map<Id, Integer> totalBySection = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Stadium_Section__c, COUNT(Id) total
            FROM Ticket__c
            WHERE Sport_Event__c = :eventId
            GROUP BY Stadium_Section__c
        ]) {
            totalBySection.put((Id)ar.get('Stadium_Section__c'), (Integer)ar.get('total'));
        }
        
        Map<Id, Integer> soldBySection = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Stadium_Section__c, COUNT(Id) sold
            FROM Ticket__c
            WHERE Sport_Event__c = :eventId
              AND Status__c = 'Sold'
            GROUP BY Stadium_Section__c
        ]) {
            soldBySection.put((Id)ar.get('Stadium_Section__c'), (Integer)ar.get('sold'));
        }
        
        for (Id sectionId : totalBySection.keySet()) {
            Integer total = totalBySection.get(sectionId);
            Integer sold = soldBySection.containsKey(sectionId) ? soldBySection.get(sectionId) : 0;
            Decimal percent = total > 0 ? (Decimal)sold / total * 100 : 0;
            result.put(sectionId, percent);
        }
        
        return result;
    }
}