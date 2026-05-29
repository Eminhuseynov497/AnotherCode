public with sharing class LanguageCurrencySettingsController {
    private static LanguageCurrencySettings__c cachedSettings;

    @AuraEnabled
    public static LanguageCurrencySettings__c getSettings() {
        if (cachedSettings != null) {
            return cachedSettings;
        }
        String userId = UserInfo.getUserId();
        List<LanguageCurrencySettings__c> settings = [
            SELECT Id, Language__c, Currency__c
            FROM LanguageCurrencySettings__c
            WHERE SetupOwnerId = :userId
            LIMIT 1
        ];
        if (!settings.isEmpty()) {
            cachedSettings = settings[0];
            return cachedSettings;
        }
        LanguageCurrencySettings__c defaultSettings = new LanguageCurrencySettings__c(
            SetupOwnerId = userId,
            Language__c = 'en',
            Currency__c = 'USD'
        );
        insert defaultSettings;
        cachedSettings = defaultSettings;
        return defaultSettings;
    }

    @AuraEnabled
    public static void saveSettings(String language, String currencyCode) {
        String userId = UserInfo.getUserId();
        LanguageCurrencySettings__c setting = getSettings();
        if (language != null) {
            setting.Language__c = language;
        }
        if (currencyCode != null) {
            setting.Currency__c = currencyCode;
        }
        if (language == null && currencyCode == null) {
            return;
        }
        update setting;
        cachedSettings = setting;
    }
}