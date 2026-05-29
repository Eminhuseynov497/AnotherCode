public with sharing class FanTriggerHandler {
    private static Boolean isRecursive = false;

    public static void run(List<Fan__c> newRecords, Map<Id, Fan__c> oldMap,
                           Boolean isBefore, Boolean isInsert, Boolean isUpdate) {
        if (isRecursive) return;
        isRecursive = true;

        try {
            if (isBefore && (isInsert || isUpdate)) {
                handleBeforeInsertUpdate(newRecords);
            } else if (!isBefore && isInsert) {
                handleAfterInsert(newRecords);
            }
        } finally {
            isRecursive = false;
        }
    }

    private static void handleBeforeInsertUpdate(List<Fan__c> fans) {
        for (Fan__c fan : fans) {
            if (fan.Email__c != null) {
                fan.Email__c = fan.Email__c.toLowerCase().trim();
            }
        }
    }

    private static void handleAfterInsert(List<Fan__c> fans) {
        System.debug(LoggingLevel.INFO, 'Fan created: ' + fans.size() + ' new records');
    }
}