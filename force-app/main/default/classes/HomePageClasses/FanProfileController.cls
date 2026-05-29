public with sharing class FanProfileController {
    
    @AuraEnabled(cacheable=true)
    public static FanData getFanData(String fanId) {
        FanData result = new FanData();
        
        Fan__c fan = [
            SELECT Id, Name, Loyalty_Tier__c, Loyalty_Points_Balance__c, Lifetime_Points__c,
                   Total_Spend__c, Registration_Date__c
            FROM Fan__c
            WHERE Id = :fanId
            LIMIT 1
        ];
        result.fan = fan;
        
        Integer futureEventsCount = [
            SELECT COUNT()
            FROM Ticket__c
            WHERE Purchase_Order__r.Fan__c = :fanId
              AND Status__c != 'Cancelled'
              AND Sport_Event__r.Date_Time__c > TODAY
        ];
        result.futureEventsCount = futureEventsCount;
        
        result.recentOrders = [
            SELECT Id, Order_Number__c, Total_Amount__c, Status__c, Order_Date__c
            FROM Purchase_Order__c
            WHERE Fan__c = :fanId AND Status__c = 'Confirmed'
            ORDER BY Order_Date__c DESC
            LIMIT 5
        ];
        
        result.loyaltyTransactions = [
            SELECT Id, Type__c, Points__c, Reason__c, Transaction_Date__c
            FROM Loyalty_Transaction__c
            WHERE Fan__c = :fanId
            ORDER BY Transaction_Date__c DESC
            LIMIT 5
        ];
        
        result.activeSeasonPasses = [
            SELECT Id, Team__r.Name, Season__c, Payment_Plan__c
            FROM Season_Pass__c
            WHERE Fan__c = :fanId AND Status__c = 'Active'
            ORDER BY End_Date__c DESC
            LIMIT 5
        ];
        
        return result;
    }
    
    @AuraEnabled(cacheable=true)
    public static String getFanIdFromSeasonPass(String seasonPassId) {
        Season_Pass__c sp = [
            SELECT Fan__c
            FROM Season_Pass__c
            WHERE Id = :seasonPassId
            LIMIT 1
        ];
        return sp.Fan__c;
    }
    
    @AuraEnabled(cacheable=true)
    public static Fan__c getFanForCurrentUser() {
        User currentUser = [SELECT Id, Email FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        if (String.isBlank(currentUser.Email)) {
            return null;
        }
        List<Fan__c> fans = [
            SELECT Id, Name, Loyalty_Tier__c, Loyalty_Points_Balance__c, Lifetime_Points__c,
                   Total_Spend__c, Registration_Date__c
            FROM Fan__c
            WHERE Email__c = :currentUser.Email
            LIMIT 1
        ];
        return fans.isEmpty() ? null : fans[0];
    }
    
    public class FanData {
        @AuraEnabled public Fan__c fan;
        @AuraEnabled public Integer futureEventsCount;
        @AuraEnabled public List<Purchase_Order__c> recentOrders;
        @AuraEnabled public List<Loyalty_Transaction__c> loyaltyTransactions;
        @AuraEnabled public List<Season_Pass__c> activeSeasonPasses;
    }
}