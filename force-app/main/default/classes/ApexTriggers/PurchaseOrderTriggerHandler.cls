public with sharing class PurchaseOrderTriggerHandler {
    private static Boolean isRecursive = false;

    public static void run(List<Purchase_Order__c> newRecords, Map<Id, Purchase_Order__c> oldMap,
                           Boolean isBefore, Boolean isInsert, Boolean isUpdate) {
        if (isRecursive) return;
        isRecursive = true;

        try {
            if (isBefore && isInsert) {
                handleBeforeInsert(newRecords);
            } else if (!isBefore && (isInsert || isUpdate)) {
                handleAfterInsertOrUpdate(newRecords, oldMap, isInsert);
            }
        } finally {
            isRecursive = false;
        }
    }

    private static void handleBeforeInsert(List<Purchase_Order__c> orders) {
        for (Purchase_Order__c po : orders) {
            if (String.isBlank(po.Order_Number__c)) {
                po.Order_Number__c = generateOrderNumber();
            }
        }
    }

    private static void handleAfterInsertOrUpdate(List<Purchase_Order__c> newOrders,
                                                  Map<Id, Purchase_Order__c> oldMap,
                                                  Boolean isInsert) {
        Set<Id> confirmedOrders = new Set<Id>();
        Set<Id> cancelledOrRefundedOrders = new Set<Id>();
        Set<Id> allAffectedEvents = new Set<Id>();

        for (Purchase_Order__c po : newOrders) {
            String oldStatus = (oldMap != null && oldMap.containsKey(po.Id)) ? oldMap.get(po.Id).Status__c : null;
            String newStatus = po.Status__c;

            if (newStatus == 'Confirmed' && oldStatus != 'Confirmed') {
                confirmedOrders.add(po.Id);
                allAffectedEvents.add(po.Sport_Event__c);
            }

            if ((newStatus == 'Cancelled' || newStatus == 'Refunded') &&
                oldStatus != 'Cancelled' && oldStatus != 'Refunded') {
                cancelledOrRefundedOrders.add(po.Id);
                allAffectedEvents.add(po.Sport_Event__c);
            }
        }

        if (!confirmedOrders.isEmpty()) {
            processConfirmedOrders(confirmedOrders);
        }

        if (!cancelledOrRefundedOrders.isEmpty()) {
            processCancelledOrRefundedOrders(cancelledOrRefundedOrders);
        }

        if (!allAffectedEvents.isEmpty()) {
            TicketInventoryService.updateEventAvailabilityStatus(allAffectedEvents);
        }
    }

    private static void processConfirmedOrders(Set<Id> orderIds) {
        for (Id orderId : orderIds) {
            try {
                LoyaltyService.awardPurchasePoints(orderId);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Ошибка начисления баллов за заказ ' + orderId + ': ' + e.getMessage());
            }
        }
    }

    private static void processCancelledOrRefundedOrders(Set<Id> orderIds) {
        if (orderIds.isEmpty()) return;

        Map<Id, Purchase_Order__c> ordersMap = new Map<Id, Purchase_Order__c>([
            SELECT Id, Sport_Event__c, Loyalty_Points_Used__c
            FROM Purchase_Order__c
            WHERE Id IN :orderIds
        ]);

        List<Ticket__c> ticketsToRelease = [
            SELECT Id, Status__c
            FROM Ticket__c
            WHERE Purchase_Order__c IN :orderIds AND Status__c = 'Sold'
            FOR UPDATE
        ];

        for (Ticket__c t : ticketsToRelease) {
            t.Status__c = 'Available';
            t.Purchase_Order__c = null;
            t.Reserved_Until__c = null;
        }
        update ticketsToRelease;

        for (Purchase_Order__c order : ordersMap.values()) {
            if (order.Loyalty_Points_Used__c > 0) {
                try {
                    RefundService.restoreRedeemedPoints(order.Id);
                } catch (Exception e) {
                    System.debug(LoggingLevel.ERROR, 'Ошибка восстановления баллов по заказу ' + order.Id + ': ' + e.getMessage());
                }
            }
        }
    }

    private static String generateOrderNumber() {
        String timestamp = Datetime.now().format('yyyyMMddHHmmssSSS');
        Integer randomNum = Integer.valueOf(Math.floor(Math.random() * 10000));
        return 'PO-' + timestamp + '-' + String.valueOf(randomNum);
    }
}