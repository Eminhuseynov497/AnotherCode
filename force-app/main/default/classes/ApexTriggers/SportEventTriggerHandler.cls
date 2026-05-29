public with sharing class SportEventTriggerHandler {
    private static Boolean isRecursive = false;

    public static void run(List<Sport_Event__c> newRecords, Map<Id, Sport_Event__c> oldMap) {
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

    private static void handleAfterInsert(List<Sport_Event__c> newEvents) {
        Set<Id> eventsForTicketGen = new Set<Id>();

        for (Sport_Event__c evt : newEvents) {
            if (evt.Status__c == 'On Sale') {
                eventsForTicketGen.add(evt.Id);
            }
        }

        if (!eventsForTicketGen.isEmpty()) {
            enqueueTicketGenerationAndSeasonReservation(eventsForTicketGen);
        }
    }

    private static void handleAfterUpdate(List<Sport_Event__c> newEvents, Map<Id, Sport_Event__c> oldMap) {
        Set<Id> eventsForTicketGen = new Set<Id>();
        Set<Id> eventsForPriceRecalc = new Set<Id>();
        Set<Id> eventsForRefund = new Set<Id>();
        Set<Id> eventsForAttendance = new Set<Id>();

        for (Sport_Event__c evt : newEvents) {
            Sport_Event__c old = oldMap.get(evt.Id);
            if (old == null) continue;

            if (evt.Status__c == 'On Sale' && old.Status__c != 'On Sale') {
                eventsForTicketGen.add(evt.Id);
            }

            if (evt.Event_Type__c != old.Event_Type__c || evt.Date_Time__c != old.Date_Time__c) {
                eventsForPriceRecalc.add(evt.Id);
            }

            if (evt.Status__c == 'Cancelled' && old.Status__c != 'Cancelled') {
                eventsForRefund.add(evt.Id);
            }

            if (evt.Status__c == 'Completed' && old.Status__c != 'Completed') {
                eventsForAttendance.add(evt.Id);
            }
        }

        if (!eventsForTicketGen.isEmpty()) {
            enqueueTicketGenerationAndSeasonReservation(eventsForTicketGen);
        }

        if (!eventsForPriceRecalc.isEmpty()) {
            enqueuePriceRecalculation(eventsForPriceRecalc);
        }

        for (Id eventId : eventsForRefund) {
            enqueueRefundProcessing(eventId);
        }

        for (Id eventId : eventsForAttendance) {
            enqueueAttendancePoints(eventId);
        }
    }


    private static void enqueueTicketGenerationAndSeasonReservation(Set<Id> eventIds) {
        System.enqueueJob(new TicketGenerationQueueable(eventIds));
    }

    private static void enqueuePriceRecalculation(Set<Id> eventIds) {
        System.enqueueJob(new PriceRecalculationQueueable(eventIds));
    }

    private static void enqueueRefundProcessing(Id eventId) {
        System.enqueueJob(new RefundProcessingQueueable(eventId));
    }

    private static void enqueueAttendancePoints(Id eventId) {
        System.enqueueJob(new AttendancePointsQueueable(eventId));
    }


    public class PriceRecalculationQueueable implements Queueable {
        private Set<Id> eventIds;
        public PriceRecalculationQueueable(Set<Id> eventIds) {
            this.eventIds = eventIds;
        }
        public void execute(QueueableContext context) {
            DynamicPricingService.recalculateEventPrices(eventIds);
        }
    }

    public class RefundProcessingQueueable implements Queueable {
        private Id eventId;
        public RefundProcessingQueueable(Id eventId) {
            this.eventId = eventId;
        }
        public void execute(QueueableContext context) {
            RefundService.processEventCancellation(eventId);
        }
    }

    public class AttendancePointsQueueable implements Queueable {
        private Id eventId;
        public AttendancePointsQueueable(Id eventId) {
            this.eventId = eventId;
        }
        public void execute(QueueableContext context) {
            LoyaltyService.awardAttendancePoints(eventId);
        }
    }
}