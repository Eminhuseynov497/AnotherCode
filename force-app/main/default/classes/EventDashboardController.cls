public with sharing class EventDashboardController {

    @AuraEnabled(cacheable=true)
    public static DashboardData getDashboardData(Id eventId) {
        DashboardData d = new DashboardData();

        Sport_Event__c evt = [
            SELECT Id, Total_Tickets__c, Tickets_Sold__c, Occupancy_Percent__c,
                   (SELECT Id, Stadium_Section__r.Name, Stadium_Section__c, Status__c FROM Tickets__r)
            FROM Sport_Event__c WHERE Id = :eventId
        ];

        d.totalTickets = evt.Total_Tickets__c != null ? Integer.valueOf(evt.Total_Tickets__c) : 0;
        d.ticketsSold = evt.Tickets_Sold__c != null ? Integer.valueOf(evt.Tickets_Sold__c) : 0;
        d.occupancyPercent = evt.Occupancy_Percent__c != null ? evt.Occupancy_Percent__c : 0;

        AggregateResult[] revAgg = [
            SELECT SUM(Total_Amount__c) total
            FROM Purchase_Order__c
            WHERE Sport_Event__c = :eventId AND Status__c = 'Confirmed'
        ];
        d.totalRevenue = revAgg[0].get('total') != null ? (Decimal)revAgg[0].get('total') : 0;

        Map<Id, Integer> soldBySection = new Map<Id, Integer>();
        for (Ticket__c t : evt.Tickets__r) {
            if (t.Status__c == 'Sold') {
                Integer cnt = soldBySection.get(t.Stadium_Section__c);
                soldBySection.put(t.Stadium_Section__c, cnt != null ? cnt + 1 : 1);
            }
        }

        List<Stadium_Section__c> sections = [
            SELECT Id, Name, Total_Seats__c
            FROM Stadium_Section__c
            WHERE Stadium__c = :evt.Stadium__c AND Is_Active__c = true
        ];

        d.sectionOccupancy = new List<SectionOccupancy>();
        for (Stadium_Section__c sec : sections) {
            Integer sold = soldBySection.get(sec.Id) != null ? soldBySection.get(sec.Id) : 0;
            Integer total = sec.Total_Seats__c != null ? Integer.valueOf(sec.Total_Seats__c) : 0;
            Decimal percent = total > 0 ? (Decimal.valueOf(sold) / total) * 100 : 0;
            d.sectionOccupancy.add(new SectionOccupancy(sec.Name, sold, total, percent));
        }

        List<Purchase_Order__c> recentOrders = [
            SELECT Order_Number__c, Fan__r.First_Name__c, Fan__r.Last_Name__c,
                   Order_Date__c, Total_Amount__c, Status__c
            FROM Purchase_Order__c
            WHERE Sport_Event__c = :eventId
            ORDER BY Order_Date__c DESC
            LIMIT 5
        ];

        d.recentOrders = new List<OrderDTO>();
        for (Purchase_Order__c po : recentOrders) {
            String fanName = (po.Fan__r != null ? (po.Fan__r.First_Name__c + ' ' + po.Fan__r.Last_Name__c) : 'Unknown');
            d.recentOrders.add(new OrderDTO(po.Order_Number__c, fanName, po.Order_Date__c, po.Total_Amount__c, po.Status__c));
        }

        return d;
    }

    public class DashboardData {
        @AuraEnabled public Integer totalTickets;
        @AuraEnabled public Integer ticketsSold;
        @AuraEnabled public Decimal occupancyPercent;
        @AuraEnabled public Decimal totalRevenue;
        @AuraEnabled public List<SectionOccupancy> sectionOccupancy;
        @AuraEnabled public List<OrderDTO> recentOrders;
    }

    public class SectionOccupancy {
        @AuraEnabled public String sectionName;
        @AuraEnabled public Integer soldCount;
        @AuraEnabled public Integer totalCount;
        @AuraEnabled public Decimal percent;
        public SectionOccupancy(String name, Integer sold, Integer total, Decimal pct) {
            this.sectionName = name;
            this.soldCount = sold;
            this.totalCount = total;
            this.percent = pct.setScale(0, RoundingMode.HALF_UP);
        }
    }

    public class OrderDTO {
        @AuraEnabled public String orderNumber;
        @AuraEnabled public String fanName;
        @AuraEnabled public Datetime orderDate;
        @AuraEnabled public Decimal totalAmount;
        @AuraEnabled public String status;
        public OrderDTO(String orderNum, String fan, Datetime dt, Decimal amount, String st) {
            this.orderNumber = orderNum;
            this.fanName = fan;
            this.orderDate = dt;
            this.totalAmount = amount;
            this.status = st;
        }
    }
}