public with sharing class TicketTriggerHandler {
    private static Boolean isRecursive = false;

    public static void run(List<Ticket__c> newTickets, Map<Id, Ticket__c> oldMap,
                           Boolean isBefore, Boolean isInsert, Boolean isUpdate) {
        if (isRecursive) return;
        isRecursive = true;

        try {
            if (isBefore) {
                if (isInsert) {
                    handleBeforeInsert(newTickets);
                } else if (isUpdate) {
                    handleBeforeUpdate(newTickets, oldMap);
                }
            } else if (!isBefore && isUpdate) {
                handleAfterUpdate(newTickets, oldMap);
            }
        } finally {
            isRecursive = false;
        }
    }

    private static void handleBeforeInsert(List<Ticket__c> tickets) {
        for (Ticket__c t : tickets) {
            if (String.isBlank(t.QR_Code__c)) {
                t.QR_Code__c = generateQRCode();
            }
            if (String.isBlank(t.Seat_Key__c)) {
                t.Seat_Key__c = t.Sport_Event__c + '-' + t.Stadium_Section__c + '-' +
                                t.Row_Number__c + '-' + t.Seat_Number__c;
            }
        }
    }

    private static void handleBeforeUpdate(List<Ticket__c> newTickets, Map<Id, Ticket__c> oldMap) {
        for (Ticket__c t : newTickets) {
            Ticket__c old = oldMap.get(t.Id);
            if (old == null || t.Status__c == old.Status__c) continue;
            validateStatusTransition(old.Status__c, t.Status__c);
        }
    }

    private static void handleAfterUpdate(List<Ticket__c> newTickets, Map<Id, Ticket__c> oldMap) {
        List<Ticket__c> checkedInTickets = new List<Ticket__c>();

        for (Ticket__c t : newTickets) {
            Ticket__c old = oldMap.get(t.Id);
            if (old == null) continue;
            if (t.Status__c == 'Checked In' && old.Status__c != 'Checked In') {
                t.Checked_In_At__c = System.now();
                checkedInTickets.add(t);
            }
        }

        if (!checkedInTickets.isEmpty()) {
            List<Ticket__c> updates = new List<Ticket__c>();
            for (Ticket__c t : checkedInTickets) {
                updates.add(new Ticket__c(Id = t.Id, Checked_In_At__c = t.Checked_In_At__c));
            }
            update updates;
        }
    }

    private static void validateStatusTransition(String oldStatus, String newStatus) {
        if (oldStatus == 'Checked In' || oldStatus == 'Cancelled') {
            throw new TicketTriggerException('Нельзя изменить статус билета из "' + oldStatus + '".');
        }

        if (oldStatus == 'Available' && newStatus == 'Checked In') {
            throw new TicketTriggerException('Нельзя отметить билет, который ещё не продан.');
        }

        if (oldStatus == 'Reserved' && newStatus == 'Checked In') {
            throw new TicketTriggerException('Нельзя отметить зарезервированный билет.');
        }

        if (oldStatus == 'Sold' && newStatus == 'Available') {
            throw new TicketTriggerException('Нельзя вернуть билет в доступные напрямую, используйте отмену заказа.');
        }

        if (newStatus == 'Reserved' && oldStatus != 'Available') {
            throw new TicketTriggerException('Нельзя зарезервировать билет, который уже не доступен.');
        }

    }

    private static String generateQRCode() {
        String random = Crypto.getRandomLong() + '-' + System.now().getTime();
        Blob hash = Crypto.generateDigest('SHA-256', Blob.valueOf(random));
        return EncodingUtil.convertToHex(hash);
    }

    public class TicketTriggerException extends Exception {}
}