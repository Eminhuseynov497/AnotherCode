public with sharing class DynamicPricingService {
    private static final Map<String, Decimal> EVENT_TYPE_MULTIPLIER = new Map<String, Decimal>{
        'Regular Season' => 1.00,
        'Friendly' => 1.00,
        'Exhibition' => 1.00,
        'Derby' => 1.40,
        'Playoff' => 1.70,
        'Quarter-Final' => 1.70,
        'Semi-Final' => 2.00,
        'Cup Match' => 1.50,
        'Final' => 2.50
    };

    private static final Map<String, Decimal> LOYALTY_DISCOUNT = new Map<String, Decimal>{
        'Bronze' => 0.00,
        'Silver' => 0.05,
        'Gold' => 0.10,
        'Platinum' => 0.15
    };


    /**
     * Calculate dynamic price for a single ticket.
     * @param ticket
     * @param event
     * @param sectionSoldPercent
     * @return Decimal dynamic price
     */
    public static Decimal calculateTicketPrice(Ticket__c ticket, Sport_Event__c event, Decimal sectionSoldPercent) {
        if (ticket == null || event == null) return 0.0;
        Decimal base = ticket.Base_Price__c != null ? ticket.Base_Price__c : 0;
        Decimal eventMult = getEventMultiplier(event.Event_Type__c);
        Decimal demand = getDemandFactor(sectionSoldPercent);
        Decimal timeFactor = getTimeFactor(event.Date_Time__c);
        Decimal dynamic = base * eventMult * demand * timeFactor;
        return roundPrice(dynamic);
    }

    public static void recalculateEventPrices(Set<Id> eventIds) {
        if (eventIds == null || eventIds.isEmpty()) return;

        List<Sport_Event__c> events = [
            SELECT Id, Event_Type__c, Date_Time__c,
                (SELECT Id, Base_Price__c, Stadium_Section__c, Status__c
                 FROM Tickets__r
                 WHERE Status__c IN ('Available', 'Reserved'))
            FROM Sport_Event__c
            WHERE Id IN :eventIds
        ];

        Map<Id, Map<Id, Decimal>> sectionSoldPercentCache = new Map<Id, Map<Id, Decimal>>();

        List<Ticket__c> ticketsToUpdate = new List<Ticket__c>();
        for (Sport_Event__c evt : events) {
            for (Ticket__c t : evt.Tickets__r) {
                Decimal soldPercent = getSectionSoldPercent(evt.Id, t.Stadium_Section__c, sectionSoldPercentCache);
                t.Dynamic_Price__c = calculateTicketPrice(t, evt, soldPercent);
                ticketsToUpdate.add(new Ticket__c(Id = t.Id, Dynamic_Price__c = t.Dynamic_Price__c));
            }
        }
        if (!ticketsToUpdate.isEmpty()) {
            update ticketsToUpdate;
        }
    }

    public static void recalculateSectionPrices(Id eventId, Id sectionId) {
        if (eventId == null || sectionId == null) return;

        Sport_Event__c event = [
            SELECT Id, Event_Type__c, Date_Time__c
            FROM Sport_Event__c
            WHERE Id = :eventId
        ];

        List<Ticket__c> tickets = [
            SELECT Id, Base_Price__c, Stadium_Section__c, Status__c
            FROM Ticket__c
            WHERE Sport_Event__c = :eventId
              AND Stadium_Section__c = :sectionId
              AND Status__c IN ('Available', 'Reserved')
        ];

        Decimal soldPercent = getSectionSoldPercent(eventId, sectionId, new Map<Id, Map<Id, Decimal>>());

        List<Ticket__c> toUpdate = new List<Ticket__c>();
        for (Ticket__c t : tickets) {
            t.Dynamic_Price__c = calculateTicketPrice(t, event, soldPercent);
            toUpdate.add(new Ticket__c(Id = t.Id, Dynamic_Price__c = t.Dynamic_Price__c));
        }
        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    public static Map<String, Decimal> getEventPriceSummary(Id eventId) {
        AggregateResult[] results = [
            SELECT MIN(Dynamic_Price__c) minPrice, MAX(Dynamic_Price__c) maxPrice, AVG(Dynamic_Price__c) avgPrice
            FROM Ticket__c
            WHERE Sport_Event__c = :eventId
              AND Status__c IN ('Available', 'Reserved')
        ];
        Map<String, Decimal> summary = new Map<String, Decimal>();
        if (!results.isEmpty() && results[0].get('minPrice') != null) {
            summary.put('min', (Decimal)results[0].get('minPrice'));
            summary.put('max', (Decimal)results[0].get('maxPrice'));
            summary.put('avg', (Decimal)results[0].get('avgPrice'));
        }
        return summary;
    }

    public static Decimal getLoyaltyDiscountPercent(Id fanId) {
        if (fanId == null) return 0.0;
        Fan__c fan = [SELECT Loyalty_Tier__c FROM Fan__c WHERE Id = :fanId LIMIT 1];
        String tier = fan.Loyalty_Tier__c != null ? fan.Loyalty_Tier__c : 'Bronze';
        return LOYALTY_DISCOUNT.containsKey(tier) ? LOYALTY_DISCOUNT.get(tier) : 0.0;
    }

    private static Decimal getEventMultiplier(String eventType) {
        if (eventType == null) return 1.0;
        return EVENT_TYPE_MULTIPLIER.containsKey(eventType) ? EVENT_TYPE_MULTIPLIER.get(eventType) : 1.0;
    }

    private static Decimal getDemandFactor(Decimal soldPercent) {
        if (soldPercent == null || soldPercent < 50) return 1.00;
        if (soldPercent <= 69) return 1.10;
        if (soldPercent <= 84) return 1.20;
        return 1.35;
    }

    private static Decimal getTimeFactor(Datetime eventDateTime) {
        if (eventDateTime == null) return 1.0;
        Long hoursRemaining = (eventDateTime.getTime() - System.now().getTime()) / (1000 * 60 * 60);
        if (hoursRemaining < 0) hoursRemaining = 0;
        if (hoursRemaining > 30 * 24) return 0.95;
        if (hoursRemaining > 7 * 24) return 1.00;
        if (hoursRemaining > 2 * 24) return 1.10;
        return 1.25;
    }

    private static Decimal getSectionSoldPercent(Id eventId, Id sectionId, Map<Id, Map<Id, Decimal>> cache) {
        if (!cache.containsKey(eventId)) {
            List<AggregateResult> aggr = [
                SELECT Stadium_Section__c, COUNT(Id) totalSold
                FROM Ticket__c
                WHERE Sport_Event__c = :eventId
                  AND Status__c = 'Sold'
                GROUP BY Stadium_Section__c
            ];
            Map<Id, Decimal> sectionMap = new Map<Id, Decimal>();
            for (AggregateResult ar : aggr) {
                Id secId = (Id)ar.get('Stadium_Section__c');
                Integer sold = (Integer)ar.get('totalSold');
                Integer totalSeats = getSectionTotalSeats(secId);
                Decimal percent = totalSeats > 0 ? (Decimal.valueOf(sold) / totalSeats) * 100 : 0;
                sectionMap.put(secId, percent);
            }
            cache.put(eventId, sectionMap);
        }
        Map<Id, Decimal> eventMap = cache.get(eventId);
        if (eventMap.containsKey(sectionId)) {
            return eventMap.get(sectionId);
        }
        return 0;
    }

    private static Integer getSectionTotalSeats(Id sectionId) {
        Stadium_Section__c sec = [
            SELECT Row_Count__c, Seats_Per_Row__c
            FROM Stadium_Section__c
            WHERE Id = :sectionId
        ];
        return (sec.Row_Count__c != null ? sec.Row_Count__c.intValue() : 0) *
               (sec.Seats_Per_Row__c != null ? sec.Seats_Per_Row__c.intValue() : 0);
    }

    private static Decimal roundPrice(Decimal value) {
        if (value == null) return 0.0;
        return value.setScale(2, System.RoundingMode.HALF_UP);
    }
}