public with sharing class SeasonPassController {
    @AuraEnabled(cacheable=true)
    public static List<Fan__c> getFans() {
        return [SELECT Id, Name, First_Name__c, Last_Name__c, Email__c, Loyalty_Tier__c
                FROM Fan__c 
                ORDER BY LastModifiedDate DESC
                LIMIT 50];
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Season_Pass__c> getSeasonPassesByFanId(Id fanId) {
        if (fanId == null) return new List<Season_Pass__c>();
        return [SELECT Id, Name, Fan__c, Fan__r.Name, Team__c, Team__r.Name, 
                       Stadium_Section__c, Stadium_Section__r.Name, Season__c, 
                       Start_Date__c, End_Date__c, Preferred_Row__c, Preferred_Seats__c,
                       Season_Pass_Price__c, Payment_Plan__c, Status__c, Auto_Renew__c
                FROM Season_Pass__c 
                WHERE Fan__c = :fanId
                ORDER BY CreatedDate DESC];
    }

    @AuraEnabled(cacheable=true)
    public static List<Fan__c> searchFans(String searchTerm) {
        String searchPattern = '%' + searchTerm + '%';
        return [SELECT Id, Name, First_Name__c, Last_Name__c, Email__c, Loyalty_Tier__c
                FROM Fan__c 
                WHERE First_Name__c LIKE :searchPattern 
                   OR Last_Name__c LIKE :searchPattern 
                   OR Email__c LIKE :searchPattern
                LIMIT 20];
    }

    @AuraEnabled(cacheable=true)
    public static List<Fan__c> getRecentFans() {
        return [SELECT Id, Name, First_Name__c, Last_Name__c, Email__c, Loyalty_Tier__c
                FROM Fan__c 
                ORDER BY LastModifiedDate DESC
                LIMIT 10];
    }

    @AuraEnabled(cacheable=true)
    public static List<Team__c> getTeams() {
        return [SELECT Id, Name FROM Team__c WHERE Is_Active__c = true ORDER BY Name];
    }

    @AuraEnabled(cacheable=true)
    public static List<Stadium_Section__c> getSectionsByTeamId(Id teamId) {
        if (teamId == null) return new List<Stadium_Section__c>();
        Team__c team = [SELECT Home_Stadium__c FROM Team__c WHERE Id = :teamId];
        if (team.Home_Stadium__c == null) return new List<Stadium_Section__c>();
        return [SELECT Id, Name, Category__c, Row_Count__c, Seats_Per_Row__c, Base_Price__c
                FROM Stadium_Section__c 
                WHERE Stadium__c = :team.Home_Stadium__c AND Is_Active__c = true
                ORDER BY Sort_Order__c, Name];
    }

    @AuraEnabled
    public static Season_Pass__c saveSeasonPass(Season_Pass__c seasonPass, Id fanId) {
        if (fanId == null) throw new AuraHandledException('Please select a Fan first.');
        if (seasonPass == null) throw new AuraHandledException('Season Pass data is empty.');
        
        seasonPass.Fan__c = fanId;
        
        if (seasonPass.Team__c == null) throw new AuraHandledException('Team is required.');
        if (seasonPass.Stadium_Section__c == null) throw new AuraHandledException('Section is required.');
        if (String.isBlank(seasonPass.Season__c)) throw new AuraHandledException('Season is required.');
        if (seasonPass.Start_Date__c == null) throw new AuraHandledException('Start Date is required.');
        if (seasonPass.End_Date__c == null) throw new AuraHandledException('End Date is required.');
        if (seasonPass.End_Date__c <= seasonPass.Start_Date__c) {
            throw new AuraHandledException('End Date must be after Start Date.');
        }
        
        if (seasonPass.Status__c == null) seasonPass.Status__c = 'Active';
        if (seasonPass.Payment_Plan__c == null) seasonPass.Payment_Plan__c = 'Full';
        if (seasonPass.Season_Pass_Price__c == null) {
            seasonPass.Season_Pass_Price__c = 500;
        }
        
        upsert seasonPass;
        
        if (seasonPass.Id != null) {
            try {
                SeasonPassService.reserveFutureSeasonPassSeats(seasonPass.Id);
            } catch (Exception e) {
                System.debug('Error calling SeasonPassService: ' + e.getMessage());
            }
        }
        
        return seasonPass;
    }

    @AuraEnabled
    public static void deleteSeasonPass(Id seasonPassId) {
        if (seasonPassId == null) return;
        delete [SELECT Id FROM Season_Pass__c WHERE Id = :seasonPassId];
    }
}