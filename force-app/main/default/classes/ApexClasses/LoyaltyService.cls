public with sharing class LoyaltyService {

    private static final Integer POINTS_PER_CURRENCY_UNIT = 1;
    private static final Integer ATTENDANCE_POINTS = 100;
    private static final Integer BIRTHDAY_BONUS_POINTS = 200;

    private static final Map<String, Integer> TIER_THRESHOLDS = new Map<String, Integer>{
        'Bronze' => 0,
        'Silver' => 500,
        'Gold' => 2000,
        'Platinum' => 5000
    };

    public static void awardPurchasePoints(Id orderId) {
        if (orderId == null) return;

        Purchase_Order__c order = [
            SELECT Id, Fan__c, Total_Amount__c, Sport_Event__r.Season__c
            FROM Purchase_Order__c
            WHERE Id = :orderId
        ];

        Integer existingTx = [
            SELECT COUNT()
            FROM Loyalty_Transaction__c
            WHERE Purchase_Order__c = :orderId AND Type__c = 'Earned'
        ];
        if (existingTx > 0) return;

        Fan__c fan = [SELECT Id, Loyalty_Points_Balance__c, Lifetime_Points__c, Loyalty_Season__c FROM Fan__c WHERE Id = :order.Fan__c];

        Integer pointsToAward = (Integer)Math.floor(order.Total_Amount__c * POINTS_PER_CURRENCY_UNIT);

        fan.Loyalty_Points_Balance__c += pointsToAward;
        fan.Lifetime_Points__c += pointsToAward;

        if (order.Sport_Event__r.Season__c != null) {
            fan.Loyalty_Season__c = order.Sport_Event__r.Season__c;
        }

        update fan;

        Loyalty_Transaction__c tx = new Loyalty_Transaction__c(
            Fan__c = fan.Id,
            Purchase_Order__c = orderId,
            Type__c = 'Earned',
            Reason__c = 'Purchase',
            Points__c = pointsToAward,
            Transaction_Date__c = System.now(),
            Balance_After__c = fan.Loyalty_Points_Balance__c
        );
        insert tx;

        evaluateTier(new Set<Id>{ fan.Id });
    }

    public static void redeemPoints(Id fanId, Integer points, Id orderId) {
        if (fanId == null || points == null || points <= 0) return;

        Fan__c fan = [SELECT Id, Loyalty_Points_Balance__c FROM Fan__c WHERE Id = :fanId];

        if (fan.Loyalty_Points_Balance__c < points) {
            throw new LoyaltyException('Недостаточно баллов для погашения. Текущий баланс: ' + fan.Loyalty_Points_Balance__c);
        }

        fan.Loyalty_Points_Balance__c -= points;
        update fan;

        Loyalty_Transaction__c tx = new Loyalty_Transaction__c(
            Fan__c = fanId,
            Purchase_Order__c = orderId,
            Type__c = 'Redeemed',
            Reason__c = 'Redemption',
            Points__c = -points,
            Transaction_Date__c = System.now(),
            Balance_After__c = fan.Loyalty_Points_Balance__c
        );
        insert tx;
    }


    public static void awardAttendancePoints(Id eventId) {
        if (eventId == null) return;

        Sport_Event__c evt = [SELECT Id, Season__c FROM Sport_Event__c WHERE Id = :eventId];

        List<Ticket__c> checkedInTickets = [
            SELECT Id, Purchase_Order__r.Fan__c
            FROM Ticket__c
            WHERE Sport_Event__c = :eventId AND Status__c = 'Checked In' AND Purchase_Order__r.Fan__c != null
        ];

        Set<Id> fanIds = new Set<Id>();
        for (Ticket__c t : checkedInTickets) {
            fanIds.add(t.Purchase_Order__r.Fan__c);
        }

        if (fanIds.isEmpty()) return;

        List<Fan__c> fans = [SELECT Id, Loyalty_Points_Balance__c, Lifetime_Points__c, Loyalty_Season__c FROM Fan__c WHERE Id IN :fanIds];

        List<Loyalty_Transaction__c> transactions = new List<Loyalty_Transaction__c>();
        List<Fan__c> fansToUpdate = new List<Fan__c>();

        for (Fan__c fan : fans) {
            fan.Loyalty_Points_Balance__c += ATTENDANCE_POINTS;
            fan.Lifetime_Points__c += ATTENDANCE_POINTS;
            if (evt.Season__c != null) {
                fan.Loyalty_Season__c = evt.Season__c;
            }
            fansToUpdate.add(fan);

            Loyalty_Transaction__c tx = new Loyalty_Transaction__c(
                Fan__c = fan.Id,
                Type__c = 'Earned',
                Reason__c = 'Attendance',
                Points__c = ATTENDANCE_POINTS,
                Transaction_Date__c = System.now(),
                Balance_After__c = fan.Loyalty_Points_Balance__c
            );
            transactions.add(tx);
        }

        update fansToUpdate;

        Map<Id, Fan__c> updatedFansMap = new Map<Id, Fan__c>(fansToUpdate);
        for (Loyalty_Transaction__c tx : transactions) {
            tx.Balance_After__c = updatedFansMap.get(tx.Fan__c).Loyalty_Points_Balance__c;
        }
        insert transactions;

        evaluateTier(fanIds);
    }

    public static void awardBirthdayBonus() {
        Date today = Date.today();

        List<Fan__c> birthdayFans = [
            SELECT Id, Loyalty_Points_Balance__c, Lifetime_Points__c, Last_Birthday_Bonus_Date__c
            FROM Fan__c
            WHERE CALENDAR_MONTH(Date_of_Birth__c) = :today.month()
              AND DAY_IN_MONTH(Date_of_Birth__c) = :today.day()
              AND (Last_Birthday_Bonus_Date__c = NULL OR Last_Birthday_Bonus_Date__c < :today)
        ];

        if (birthdayFans.isEmpty()) return;

        List<Loyalty_Transaction__c> transactions = new List<Loyalty_Transaction__c>();
        List<Fan__c> fansToUpdate = new List<Fan__c>();

        for (Fan__c fan : birthdayFans) {
            fan.Loyalty_Points_Balance__c += BIRTHDAY_BONUS_POINTS;
            fan.Lifetime_Points__c += BIRTHDAY_BONUS_POINTS;
            fan.Last_Birthday_Bonus_Date__c = today;
            fansToUpdate.add(fan);

            Loyalty_Transaction__c tx = new Loyalty_Transaction__c(
                Fan__c = fan.Id,
                Type__c = 'Earned',
                Reason__c = 'Birthday Bonus',
                Points__c = BIRTHDAY_BONUS_POINTS,
                Transaction_Date__c = System.now(),
                Balance_After__c = fan.Loyalty_Points_Balance__c
            );
            transactions.add(tx);
        }

        update fansToUpdate;

        Map<Id, Fan__c> updatedFans = new Map<Id, Fan__c>(fansToUpdate);
        for (Loyalty_Transaction__c tx : transactions) {
            tx.Balance_After__c = updatedFans.get(tx.Fan__c).Loyalty_Points_Balance__c;
        }
        insert transactions;

        Set<Id> fanIds = new Set<Id>();
        for (Fan__c f : fansToUpdate) fanIds.add(f.Id);
        evaluateTier(fanIds);
    }

    public static void evaluateTier(Set<Id> fanIds) {
        if (fanIds == null || fanIds.isEmpty()) return;

        List<Fan__c> fans = [
            SELECT Id, Lifetime_Points__c, Loyalty_Tier__c, Loyalty_Season__c
            FROM Fan__c
            WHERE Id IN :fanIds
        ];

        List<Fan__c> fansToUpdate = new List<Fan__c>();
        for (Fan__c fan : fans) {
            String currentTier = fan.Loyalty_Tier__c;
            String newTier = determineTierFromPoints(fan.Lifetime_Points__c);

            if (isHigherTier(newTier, currentTier)) {
                fan.Loyalty_Tier__c = newTier;
                fansToUpdate.add(fan);
            }
            else if (isLowerTier(newTier, currentTier)) {
                if (String.isBlank(fan.Loyalty_Season__c)) {
                    fan.Loyalty_Tier__c = newTier;
                    fansToUpdate.add(fan);
                }
            }
        }

        if (!fansToUpdate.isEmpty()) {
            update fansToUpdate;
        }
    }

    private static String determineTierFromPoints(Decimal lifetimePoints) {
        if (lifetimePoints == null || lifetimePoints < 500) return 'Bronze';
        if (lifetimePoints < 2000) return 'Silver';
        if (lifetimePoints < 5000) return 'Gold';
        return 'Platinum';
    }

    private static Boolean isHigherTier(String t1, String t2) {
        return getTierRank(t1) > getTierRank(t2);
    }

    private static Boolean isLowerTier(String t1, String t2) {
        return getTierRank(t1) < getTierRank(t2);
    }

    private static Integer getTierRank(String tier) {
        if (tier == 'Bronze') return 1;
        if (tier == 'Silver') return 2;
        if (tier == 'Gold') return 3;
        if (tier == 'Platinum') return 4;
        return 0;
    }

    public class LoyaltyException extends Exception {}
}