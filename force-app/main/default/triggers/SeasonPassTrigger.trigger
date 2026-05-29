trigger SeasonPassTrigger on Season_Pass__c (after insert, after update) {
    SeasonPassTriggerHandler.run(Trigger.new, Trigger.oldMap);
}