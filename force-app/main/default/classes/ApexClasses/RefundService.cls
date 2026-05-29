public with sharing class RefundService {

    /**
     * @param orderId ID заказа
     */
    public static void cancelOrder(Id orderId) {
        if (orderId == null) return;

        Purchase_Order__c order = [
            SELECT Id, Status__c, Fan__c, Sport_Event__c, Loyalty_Points_Used__c
            FROM Purchase_Order__c
            WHERE Id = :orderId
            FOR UPDATE
        ];

        if (order.Status__c != 'Pending' && order.Status__c != 'Confirmed') {
            throw new RefundException('Заказ нельзя отменить в текущем статусе: ' + order.Status__c);
        }

        List<Ticket__c> tickets = [
            SELECT Id, Status__c
            FROM Ticket__c
            WHERE Purchase_Order__c = :orderId AND Status__c = 'Sold'
            FOR UPDATE
        ];

        for (Ticket__c t : tickets) {
            t.Status__c = 'Available';
            t.Purchase_Order__c = null;
            t.Reserved_Until__c = null;
        }
        update tickets;

        if (order.Loyalty_Points_Used__c > 0) {
            restoreRedeemedPoints(orderId);
        }

        order.Status__c = 'Cancelled';
        update order;

        TicketInventoryService.updateEventAvailabilityStatus(new Set<Id>{order.Sport_Event__c});
    }

    /**
     * @param eventId
     */
    public static void processEventCancellation(Id eventId) {
        if (eventId == null) return;

        List<Purchase_Order__c> orders = [
            SELECT Id
            FROM Purchase_Order__c
            WHERE Sport_Event__c = :eventId AND Status__c NOT IN ('Cancelled', 'Refunded')
        ];

        for (Purchase_Order__c order : orders) {
            try {
                cancelOrder(order.Id);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Ошибка при отмене заказа ' + order.Id + ': ' + e.getMessage());
            }
        }

        List<Ticket__c> reservedTickets = [
            SELECT Id
            FROM Ticket__c
            WHERE Sport_Event__c = :eventId AND Status__c = 'Reserved'
        ];
        for (Ticket__c t : reservedTickets) {
            t.Status__c = 'Available';
            t.Reserved_Until__c = null;
        }
        if (!reservedTickets.isEmpty()) {
            update reservedTickets;
        }

        TicketInventoryService.updateEventAvailabilityStatus(new Set<Id>{eventId});
    }

    /**
     * @param orderId
     */
    public static void restoreRedeemedPoints(Id orderId) {
        if (orderId == null) return;

        Purchase_Order__c order = [
            SELECT Id, Fan__c, Loyalty_Points_Used__c, Status__c
            FROM Purchase_Order__c
            WHERE Id = :orderId
        ];

        if (order.Loyalty_Points_Used__c == null || order.Loyalty_Points_Used__c == 0) {
            return;
        }

        Integer existingRestore = [
            SELECT COUNT()
            FROM Loyalty_Transaction__c
            WHERE Purchase_Order__c = :orderId
              AND Type__c = 'Earned'
              AND Reason__c = 'Admin Adjustment'
              AND Points__c = :order.Loyalty_Points_Used__c
        ];
        if (existingRestore > 0) return;

        Fan__c fan = [SELECT Id, Loyalty_Points_Balance__c FROM Fan__c WHERE Id = :order.Fan__c];
        fan.Loyalty_Points_Balance__c += order.Loyalty_Points_Used__c;
        update fan;

        Loyalty_Transaction__c tx = new Loyalty_Transaction__c(
            Fan__c = fan.Id,
            Purchase_Order__c = orderId,
            Type__c = 'Earned',
            Reason__c = 'Admin Adjustment',
            Points__c = order.Loyalty_Points_Used__c,
            Transaction_Date__c = System.now(),
            Balance_After__c = fan.Loyalty_Points_Balance__c
        );
        insert tx;
    }

    public class RefundException extends Exception {}
}