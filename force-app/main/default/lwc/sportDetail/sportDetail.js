import { LightningElement, api, wire } from 'lwc';
import { getRecordUi } from 'lightning/uiRecordApi';
import { NavigationMixin } from 'lightning/navigation';

const FIELDS = [
    'Sport__c.Name',
    'Sport__c.League__r.Name',
    'Sport__c.Icon__c',
    'Sport__c.Min_Age_Restriction__c',
    'Sport__c.Is_Active__c',
    'Sport__c.Description__c'
];

export default class SportDetail extends NavigationMixin(LightningElement) {
    @api recordId;

    @wire(getRecordUi, { recordIds: '$recordId', layoutTypes: ['Full'], modes: ['View'] })
    recordUi;
    get name() {
        if (this.recordUi.data) {
            const record = this.recordUi.data.records[this.recordId];
            return record?.fields?.Name?.value || 'Unnamed Sport';
        }
        return 'Unnamed Sport';
    }

    get leagueName() {
        if (this.recordUi.data) {
            const record = this.recordUi.data.records[this.recordId];
            return record?.fields?.League__r?.displayValue || record?.fields?.League__r?.value || '';
        }
        return '';
    }

    get iconDisplay() {
        if (this.recordUi.data) {
            const record = this.recordUi.data.records[this.recordId];
            return record?.fields?.Icon__c?.value || 'No icon selected';
        }
        return 'No icon selected';
    }

    get iconEmoji() {
        if (this.recordUi.data) {
            const record = this.recordUi.data.records[this.recordId];
            const val = record?.fields?.Icon__c?.value;
            return val || '🏅';
        }
        return '🏅';
    }

    get minAge() {
        if (this.recordUi.data) {
            const record = this.recordUi.data.records[this.recordId];
            return record?.fields?.Min_Age_Restriction__c?.value || 'Not specified';
        }
        return 'Not specified';
    }

    get description() {
        if (this.recordUi.data) {
            const record = this.recordUi.data.records[this.recordId];
            return record?.fields?.Description__c?.value || '';
        }
        return '';
    }

    get statusVariant() {
        if (this.recordUi.data) {
            const record = this.recordUi.data.records[this.recordId];
            const isActive = record?.fields?.Is_Active__c?.value;
            return isActive ? 'success' : 'warning';
        }
        return 'warning';
    }

    get statusLabel() {
        if (this.recordUi.data) {
            const record = this.recordUi.data.records[this.recordId];
            const isActive = record?.fields?.Is_Active__c?.value;
            return isActive ? 'Active' : 'Inactive';
        }
        return 'Inactive';
    }

    get isDescriptionEmpty() {
        if (this.recordUi.data) {
            const record = this.recordUi.data.records[this.recordId];
            return !record?.fields?.Description__c?.value;
        }
        return true;
    }

    handleEdit() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                actionName: 'edit'
            }
        });
    }

    handleBack() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Sport__c',
                actionName: 'list'
            }
        });
    }
}