trigger TicketTrigger on Ticket__c (before insert, before update, after update) {
    TicketTriggerHandler.run(Trigger.new, Trigger.oldMap, Trigger.isBefore, Trigger.isInsert, Trigger.isUpdate);
}