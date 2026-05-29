public with sharing class TicketQRController {
    @AuraEnabled
    public static TicketData getTicketData(String ticketId) {
        if (String.isBlank(ticketId)) {
            throw new AuraHandledException('ID билета не может быть пустым.');
        }

        List<Ticket__c> tickets = [SELECT Id, Seat_Label__c, Status__c, QR_Code__c,
                                          Sport_Event__r.Name, 
                                          Sport_Event__r.Date_Time__c, 
                                          Sport_Event__r.Stadium__r.Name
                                   FROM Ticket__c 
                                   WHERE Id = :ticketId LIMIT 1];
        
        if (tickets.isEmpty()) {
            throw new AuraHandledException('Билет с таким ID не найден.');
        }

        Ticket__c t = tickets[0];
        TicketData data = new TicketData();
        data.seatLabel = t.Seat_Label__c != null ? t.Seat_Label__c : '—';
        data.status = t.Status__c != null ? t.Status__c : '—';
        data.qrCodeUrl = t.QR_Code__c;
        data.eventName = t.Sport_Event__r?.Name != null ? t.Sport_Event__r.Name : '—';
        data.eventDateTime = t.Sport_Event__r?.Date_Time__c;
        data.stadiumName = t.Sport_Event__r?.Stadium__r?.Name != null ? t.Sport_Event__r.Stadium__r.Name : '—';
        return data;
    }

    @AuraEnabled
    public static String saveQRCode(String ticketId, String dataUrl) {
        if (String.isBlank(ticketId)) {
            throw new AuraHandledException('Ticket ID is required.');
        }
        if (String.isBlank(dataUrl)) {
            throw new AuraHandledException('Data URL is required.');
        }

        List<Ticket__c> tickets = [SELECT Id FROM Ticket__c WHERE Id = :ticketId LIMIT 1];
        if (tickets.isEmpty()) {
            throw new AuraHandledException('Ticket not found.');
        }
        Ticket__c ticket = tickets[0];

        String base64Data = dataUrl.substring(dataUrl.indexOf(',') + 1);
        Blob qrBlob = EncodingUtil.base64Decode(base64Data);

        ContentVersion cv = new ContentVersion();
        cv.Title = 'QR_Ticket_' + ticket.Id + '.png';
        cv.PathOnClient = 'QR_Ticket_' + ticket.Id + '.png';
        cv.VersionData = qrBlob;
        cv.IsMajorVersion = true;
        insert cv;

        String contentVersionId = cv.Id;
        String instanceUrl = System.Url.getOrgDomainUrl().toExternalForm();
        String fileUrl = instanceUrl + '/sfc/servlet.shepherd/document/download/' + contentVersionId;

        ticket.QR_Code__c = fileUrl;
        update ticket;

        return fileUrl;
    }

    public class TicketData {
        @AuraEnabled public String seatLabel;
        @AuraEnabled public String status;
        @AuraEnabled public String qrCodeUrl;
        @AuraEnabled public String eventName;
        @AuraEnabled public DateTime eventDateTime;
        @AuraEnabled public String stadiumName;
    }
}