public with sharing class FanController {
    @AuraEnabled(cacheable=true)
    public static List<Fan__c> getFans() {
        return [
            SELECT Id, Name, First_Name__c, Last_Name__c, Email__c, Phone__c,
                   Date_of_Birth__c, City__c, Favorite_Team__c, Favorite_Team__r.Name,
                   Loyalty_Tier__c, Loyalty_Points_Balance__c, Lifetime_Points__c
            FROM Fan__c
            ORDER BY CreatedDate DESC
        ];
    }
}