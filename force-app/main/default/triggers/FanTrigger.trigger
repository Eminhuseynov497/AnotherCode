trigger FanTrigger on Fan__c (before insert, before update, after insert) {
    FanTriggerHandler.run(Trigger.new, Trigger.oldMap, Trigger.isBefore, Trigger.isInsert, Trigger.isUpdate);
}