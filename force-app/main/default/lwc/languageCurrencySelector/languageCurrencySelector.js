import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getSettings from '@salesforce/apex/LanguageCurrencySettingsController.getSettings';
import saveSettings from '@salesforce/apex/LanguageCurrencySettingsController.saveSettings';

const CURRENCY_OPTIONS = [
    { label: 'USD ($)', value: 'USD' },
    { label: 'EUR (€)', value: 'EUR' },
    { label: 'GBP (£)', value: 'GBP' },
    { label: 'JPY (¥)', value: 'JPY' },
    { label: 'RUB (₽)', value: 'RUB' }
];

export default class LanguageCurrencySelector extends LightningElement {
    @track selectedCurrency = 'USD';
    currencyOptions = CURRENCY_OPTIONS;

    @wire(getSettings)
    wiredSettings({ error, data }) {
        if (data) {
            this.selectedCurrency = data.Currency__c || 'USD';
        } else if (error) {
            console.error('Ошибка загрузки настроек', error);
        }
    }

    handleCurrencyChange(event) {
        this.selectedCurrency = event.detail.value;
        this.savePreferences();
    }

    async savePreferences() {
        try {
            await saveSettings({
                language: 'en',
                currencyCode: this.selectedCurrency
            });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Settings saved',
                    message: 'Currency updated.',
                    variant: 'success'
                })
            );
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error.body?.message || 'Failed to save settings.',
                    variant: 'error'
                })
            );
        }
    }
}