public with sharing class FanProfileCardController {

    @AuraEnabled(cacheable=true)
    public static FanProfileData getFanProfile(Id fanId) {
        Fan__c fan = [
            SELECT Id, Loyalty_Tier__c, Loyalty_Points_Balance__c, Lifetime_Points__c,
                   Total_Spend__c, Registration_Date__c, Events_Attended__c,
                   Preferred_Category__c, Last_Birthday_Bonus_Date__c, Loyalty_Season__c
            FROM Fan__c WHERE Id = :fanId
        ];

        FanProfileData data = new FanProfileData();
        data.tier = fan.Loyalty_Tier__c;
        data.pointsBalance = fan.Loyalty_Points_Balance__c != null ? Integer.valueOf(fan.Loyalty_Points_Balance__c) : 0;
        data.lifetimePoints = fan.Lifetime_Points__c != null ? Integer.valueOf(fan.Lifetime_Points__c) : 0;
        data.totalSpend = fan.Total_Spend__c != null ? fan.Total_Spend__c : 0;
        data.memberSince = fan.Registration_Date__c;
        data.eventsAttended = fan.Events_Attended__c != null ? Integer.valueOf(fan.Events_Attended__c) : 0;

        Integer[] thresholds = new Integer[]{0, 500, 2000, 5000, 999999};
        String[] tiers = new String[]{'Bronze', 'Silver', 'Gold', 'Platinum'};
        Integer currentIdx = 0;
        for (Integer i = 0; i < tiers.size(); i++) {
            if (tiers[i] == data.tier) {
                currentIdx = i;
                break;
            }
        }
        data.nextTier = currentIdx < tiers.size() - 1 ? tiers[currentIdx + 1] : null;
        data.pointsToNextTier = data.nextTier != null ? thresholds[currentIdx + 1] - data.lifetimePoints : 0;
        data.progressPercent = data.nextTier != null
            ? (Decimal.valueOf(data.lifetimePoints - thresholds[currentIdx]) / (thresholds[currentIdx + 1] - thresholds[currentIdx]) * 100).setScale(0, System.RoundingMode.HALF_UP)
            : 100;

        List<Ticket__c> futureTickets = [
            SELECT Id, Seat_Label__c, Dynamic_Price__c, Status__c,
                   Sport_Event__r.Name, Sport_Event__r.Date_Time__c, Sport_Event__r.Stadium__r.Name
            FROM Ticket__c
            WHERE Purchase_Order__r.Fan__c = :fanId
              AND Sport_Event__r.Date_Time__c > :System.now()
              AND Status__c IN ('Sold', 'Checked In')
            ORDER BY Sport_Event__r.Date_Time__c ASC
            LIMIT 10
        ];
        data.futureTickets = new List<TicketDTO>();
        for (Ticket__c t : futureTickets) {
            data.futureTickets.add(new TicketDTO(t));
        }

        List<Purchase_Order__c> recentOrders = [
            SELECT Id, Order_Number__c, Order_Date__c, Total_Amount__c, Status__c
            FROM Purchase_Order__c
            WHERE Fan__c = :fanId
            ORDER BY Order_Date__c DESC
            LIMIT 5
        ];
        data.recentOrders = new List<OrderDTO>();
        for (Purchase_Order__c po : recentOrders) {
            data.recentOrders.add(new OrderDTO(po));
        }

        List<Loyalty_Transaction__c> recentTx = [
            SELECT Id, Type__c, Points__c, Reason__c, Transaction_Date__c
            FROM Loyalty_Transaction__c
            WHERE Fan__c = :fanId
            ORDER BY Transaction_Date__c DESC
            LIMIT 5
        ];
        data.recentLoyaltyTx = new List<LoyaltyTxDTO>();
        for (Loyalty_Transaction__c tx : recentTx) {
            data.recentLoyaltyTx.add(new LoyaltyTxDTO(tx));
        }

        List<Season_Pass__c> activePasses = [
            SELECT Id, Team__r.Name, Season__c, Stadium_Section__r.Name,
                   Start_Date__c, End_Date__c, Status__c
            FROM Season_Pass__c
            WHERE Fan__c = :fanId AND Status__c = 'Active'
        ];
        data.activeSeasonPasses = new List<SeasonPassDTO>();
        for (Season_Pass__c sp : activePasses) {
            data.activeSeasonPasses.add(new SeasonPassDTO(sp));
        }

        return data;
    }

    public class FanProfileData {
        @AuraEnabled public String tier;
        @AuraEnabled public Integer pointsBalance;
        @AuraEnabled public Integer lifetimePoints;
        @AuraEnabled public Decimal totalSpend;
        @AuraEnabled public Datetime memberSince;
        @AuraEnabled public Integer eventsAttended;
        @AuraEnabled public String nextTier;
        @AuraEnabled public Integer pointsToNextTier;
        @AuraEnabled public Decimal progressPercent;
        @AuraEnabled public List<TicketDTO> futureTickets;
        @AuraEnabled public List<OrderDTO> recentOrders;
        @AuraEnabled public List<LoyaltyTxDTO> recentLoyaltyTx;
        @AuraEnabled public List<SeasonPassDTO> activeSeasonPasses;
    }

    public class TicketDTO {
        @AuraEnabled public String seatLabel;
        @AuraEnabled public String eventName;
        @AuraEnabled public Datetime eventDate;
        @AuraEnabled public String stadium;
        @AuraEnabled public String status;
        @AuraEnabled public Decimal price;
        public TicketDTO(Ticket__c t) {
            this.seatLabel = t.Seat_Label__c;
            this.eventName = t.Sport_Event__r.Name;
            this.eventDate = t.Sport_Event__r.Date_Time__c;
            this.stadium = t.Sport_Event__r.Stadium__r.Name;
            this.status = t.Status__c;
            this.price = t.Dynamic_Price__c;
        }
    }

    public class OrderDTO {
        @AuraEnabled public String orderNumber;
        @AuraEnabled public Datetime orderDate;
        @AuraEnabled public Decimal totalAmount;
        @AuraEnabled public String status;
        public OrderDTO(Purchase_Order__c po) {
            this.orderNumber = po.Order_Number__c;
            this.orderDate = po.Order_Date__c;
            this.totalAmount = po.Total_Amount__c;
            this.status = po.Status__c;
        }
    }

    public class LoyaltyTxDTO {
        @AuraEnabled public String type;
        @AuraEnabled public Integer points;
        @AuraEnabled public String reason;
        @AuraEnabled public Datetime txDate;
        public LoyaltyTxDTO(Loyalty_Transaction__c tx) {
            this.type = tx.Type__c;
            this.points = tx.Points__c != null ? Integer.valueOf(tx.Points__c) : 0;
            this.reason = tx.Reason__c;
            this.txDate = tx.Transaction_Date__c;
        }
    }

    public class SeasonPassDTO {
        @AuraEnabled public String teamName;
        @AuraEnabled public String season;
        @AuraEnabled public String section;
        @AuraEnabled public Date startDate;
        @AuraEnabled public Date endDate;
        @AuraEnabled public String status;
        @AuraEnabled public String passKey;
        public SeasonPassDTO(Season_Pass__c sp) {
            this.teamName = sp.Team__r.Name;
            this.season = sp.Season__c;
            this.section = sp.Stadium_Section__r.Name;
            this.startDate = sp.Start_Date__c;
            this.endDate = sp.End_Date__c;
            this.status = sp.Status__c;
            this.passKey = this.teamName + '-' + this.season;
        }
    }
}