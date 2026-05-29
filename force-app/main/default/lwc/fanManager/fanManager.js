import { LightningElement, track, wire } from 'lwc';
import getFans from '@salesforce/apex/FanController.getFans';
import { refreshApex } from '@salesforce/apex';
const FIELDS = [
    'Fan__c.First_Name__c',
    'Fan__c.Last_Name__c',
    'Fan__c.Email__c',
    'Fan__c.Phone__c',
    'Fan__c.Date_of_Birth__c',
    'Fan__c.City__c',
    'Fan__c.Favorite_Team__c',
    'Fan__c.Loyalty_Tier__c',
    'Fan__c.Loyalty_Points_Balance__c'
];

export default class FanManager extends LightningElement {
    @track mode = 'select';
    @track selectedFanId = null;
    @track fans = [];
    @track error;
    wiredFansResult;

    fields = FIELDS;

    @wire(getFans)
    wiredFans(result) {
        this.wiredFansResult = result;
        const { data, error } = result;
        if (data) {
            this.fans = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.fans = [];
        }
    }

    handleFanSelect(event) {
        this.selectedFanId = event.currentTarget.dataset.id;
        this.mode = 'view';
    }

    handleEdit() {
        this.mode = 'edit';
    }

    handleNew() {
        this.mode = 'new';
        this.selectedFanId = null;
    }

    handleCancel() {
        if (this.selectedFanId) {
            this.mode = 'view';
        } else {
            this.mode = 'select';
        }
    }

    async handleSave(event) {
        const recordId = event.detail.id;
        this.selectedFanId = recordId;
        this.mode = 'view';
        await refreshApex(this.wiredFansResult);
    }

    handleBack() {
        this.mode = 'select';
        this.selectedFanId = null;
    }

    get selectedFanName() {
        if (this.selectedFanId) {
            const fan = this.fans.find(f => f.Id === this.selectedFanId);
            return fan ? fan.Name : 'Fan';
        }
        return '';
    }
    get showSelect() {
        return this.mode === 'select';
    }
    get showView() {
        return this.mode === 'view' && this.selectedFanId;
    }
    get showEdit() {
        return this.mode === 'edit' && this.selectedFanId;
    }
    get showNew() {
        return this.mode === 'new';
    }
}