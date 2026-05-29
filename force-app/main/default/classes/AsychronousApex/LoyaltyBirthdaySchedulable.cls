public with sharing class LoyaltyBirthdaySchedulable implements Schedulable {
    public void execute(SchedulableContext sc) {
        LoyaltyService.awardBirthdayBonus();
    }
}