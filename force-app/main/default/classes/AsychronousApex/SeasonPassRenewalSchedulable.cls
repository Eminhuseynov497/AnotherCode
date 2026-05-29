public with sharing class SeasonPassRenewalSchedulable implements Schedulable {
    public void execute(SchedulableContext sc) {
        Date today = Date.today();
        expireActivePasses(today);
        sendRenewalReminders(today);
    }

    private void expireActivePasses(Date today) {
        List<Season_Pass__c> toExpire = [
            SELECT Id
            FROM Season_Pass__c
            WHERE Status__c = 'Active' AND End_Date__c <= :today
        ];
        
        if (!toExpire.isEmpty()) {
            for (Season_Pass__c sp : toExpire) {
                sp.Status__c = 'Expired';
            }
            update toExpire;
            for (Season_Pass__c sp : toExpire) {
                SeasonPassService.releaseFutureSeasonPassSeats(sp.Id);
            }
        }
    }

    private void sendRenewalReminders(Date today) {
        Date reminderDate = today.addDays(30);
        
        List<Season_Pass__c> reminders = [
            SELECT Id, Fan__r.Email__c, Fan__r.First_Name__c, Team__r.Name, End_Date__c
            FROM Season_Pass__c
            WHERE Status__c = 'Active'
              AND Auto_Renew__c = false
              AND End_Date__c = :reminderDate
        ];
        
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        for (Season_Pass__c sp : reminders) {
            if (String.isNotBlank(sp.Fan__r.Email__c)) {
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(new String[] { sp.Fan__r.Email__c });
                mail.setSubject('Season Pass Renewal Reminder');
                String body = 'Dear ' + sp.Fan__r.First_Name__c + ',\n\n'
                            + 'Your season pass for ' + sp.Team__r.Name + ' will expire on ' 
                            + sp.End_Date__c.format() + '.\n'
                            + 'Please renew it before it expires to continue enjoying benefits.\n\n'
                            + 'Thank you,\nArenaHub';
                mail.setPlainTextBody(body);
                emails.add(mail);
            }
        }
        
        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails);
        }
    }
}