public with sharing class HotEventsController {
    @AuraEnabled(cacheable=true)
    public static List<Sport_Event__c> getHotEvents() {
        return [
            SELECT Id, Name, Date_Time__c, Status__c, Occupancy_Percent__c,
                   Home_Team__r.Name, Away_Team__r.Name, Stadium__r.Name,
                   Price_Multiplier__c
            FROM Sport_Event__c
            WHERE Status__c IN ('On Sale', 'Scheduled')
            ORDER BY Occupancy_Percent__c DESC, Date_Time__c ASC
            LIMIT 10
        ];
    }
}