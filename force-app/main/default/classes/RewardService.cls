public with sharing class RewardService {
    @AuraEnabled(cacheable=true)
    public static List<Reward__c> getAvailableRewards() {
        return [
            SELECT Id, Name, Description__c, Points_Cost__c, Category__c,
                   Image_URL__c, Stock_Quantity__c
            FROM Reward__c
            WHERE Is_Active__c = true
            ORDER BY Points_Cost__c ASC
        ];
    }
    
    @AuraEnabled(cacheable=false)
    public static Decimal getFanBalance(Id fanId) {
        try {
            if (fanId == null) {
                throw new AuraHandledException('Fan ID is required');
            }
            
            Fan__c fan = [
                SELECT Loyalty_Points_Balance__c
                FROM Fan__c
                WHERE Id = :fanId
                LIMIT 1
            ];
            
            // Return 0 if the field is null, otherwise return the actual value
            return fan.Loyalty_Points_Balance__c != null ? fan.Loyalty_Points_Balance__c : 0;
        } catch (QueryException e) {
            throw new AuraHandledException('Fan record not found: ' + e.getMessage());
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving fan balance: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void redeemReward(Id fanId, Id rewardId) {
        Reward__c reward = [
            SELECT Id, Name, Points_Cost__c, Stock_Quantity__c
            FROM Reward__c
            WHERE Id = :rewardId AND Is_Active__c = true
            LIMIT 1
        ];
        
        if (reward.Stock_Quantity__c != null && reward.Stock_Quantity__c <= 0) {
            throw new AuraHandledException('Вознаграждение закончилось');
        }

        Fan__c fan = [
            SELECT Id, Loyalty_Points_Balance__c
            FROM Fan__c
            WHERE Id = :fanId
            FOR UPDATE
        ];
        
        if (fan.Loyalty_Points_Balance__c < reward.Points_Cost__c) {
            throw new AuraHandledException('Недостаточно баллов');
        }

        fan.Loyalty_Points_Balance__c -= reward.Points_Cost__c;
        update fan;
        
        if (reward.Stock_Quantity__c != null) {
            reward.Stock_Quantity__c -= 1;
            update reward;
        }
        
        Reward_Redemption__c redemption = new Reward_Redemption__c(
            Fan__c = fanId,
            Reward__c = rewardId,
            Points_Cost__c = reward.Points_Cost__c,
            Redemption_Date__c = System.now(),
            Status__c = 'Pending'
        );
        insert redemption;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Reward_Redemption__c> getRedemptionHistory(Id fanId) {
        return [
            SELECT Id, Reward__r.Name, Points_Cost__c, Redemption_Date__c,
                   Status__c, Fulfillment_Details__c
            FROM Reward_Redemption__c
            WHERE Fan__c = :fanId
            ORDER BY Redemption_Date__c DESC
        ];
    }
}