public with sharing class SeasonPassTriggerHandler {
    private static Boolean isRecursive = false;

    public static void run(List<Season_Pass__c> newRecords, Map<Id, Season_Pass__c> oldMap) {
        if (isRecursive) return;
        isRecursive = true;

        try {
            if (Trigger.isAfter) {
                if (Trigger.isInsert) {
                    handleAfterInsert(newRecords);
                } else if (Trigger.isUpdate) {
                    handleAfterUpdate(newRecords, oldMap);
                }
            }
        } finally {
            isRecursive = false;
        }
    }

    private static void handleAfterInsert(List<Season_Pass__c> seasonPasses) {
        for (Season_Pass__c sp : seasonPasses) {
            SeasonPassService.reserveFutureSeasonPassSeats(sp.Id);
        }
    }

    private static void handleAfterUpdate(List<Season_Pass__c> newRecords, Map<Id, Season_Pass__c> oldMap) {
        for (Season_Pass__c sp : newRecords) {
            Season_Pass__c old = oldMap.get(sp.Id);
            if (old != null && sp.Status__c == 'Cancelled' && old.Status__c != 'Cancelled') {
                SeasonPassService.releaseFutureSeasonPassSeats(sp.Id);
            }
        }
    }
}