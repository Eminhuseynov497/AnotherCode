import { LightningElement, api, track, wire } from 'lwc';
import getSeasonPasses from '@salesforce/apex/SeasonPassController.getSeasonPassesByFanId';
import getFans from '@salesforce/apex/SeasonPassController.getFans';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class SeasonPassManager extends LightningElement {
    @api recordId;
    @track seasonPasses = [];
    @track selectedPass = null;
    @track selectedPassId = null;
    @track showForm = false;
    @track showDetails = false;
    @track editingPassId = null;
    @track teamId = null;
    @track sectionId = null;
    @track fans = [];
    @track selectedFanId = null;
    @track showFanSelector = false;

    connectedCallback() {
        if (this.recordId) {
            this.selectedFanId = this.recordId;
            this.loadSeasonPasses();
        } else {
            this.showFanSelector = true;
            this.loadFans();
        }
    }

    loadFans() {
        getFans()
            .then(data => {
                this.fans = data;
                if (data.length === 0) {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'No Fans',
                        message: 'Please create a Fan record first.',
                        variant: 'warning'
                    }));
                }
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error loading fans',
                    message: error.body.message,
                    variant: 'error'
                }));
            });
    }

    loadSeasonPasses() {
        if (!this.selectedFanId) return;
        getSeasonPasses({ fanId: this.selectedFanId })
            .then(data => {
                this.seasonPasses = data;
                if (data.length > 0) {
                    this.selectedPass = data[0];
                    this.selectedPassId = data[0].Id;
                    this.showDetails = true;
                    this.showForm = false;
                } else {
                    this.handleNewPass();
                }
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error loading season passes',
                    message: error.body.message,
                    variant: 'error'
                }));
            });
    }

    get fanOptions() {
        return this.fans.map(fan => ({
            label: `${fan.First_Name__c} ${fan.Last_Name__c} (${fan.Email__c})`,
            value: fan.Id
        }));
    }

    handleFanChange(event) {
        this.selectedFanId = event.detail.value;
        this.seasonPasses = [];
        this.selectedPass = null;
        this.showDetails = false;
        this.showForm = false;
        this.loadSeasonPasses();
    }

    get hasFanSelected() {
        return this.selectedFanId != null;
    }
    get showSeasonPassSelector() {
        return this.seasonPasses.length > 1 && !this.showForm && this.showDetails;
    }
    get seasonPassOptions() {
        return this.seasonPasses.map(pass => ({
            label: `${pass.Team__r?.Name || ''} - ${pass.Season__c || ''} (${pass.Status__c || ''})`,
            value: pass.Id
        }));
    }
    get formattedStartDate() {
        return this.selectedPass?.Start_Date__c ? new Date(this.selectedPass.Start_Date__c).toLocaleDateString() : '';
    }
    get formattedEndDate() {
        return this.selectedPass?.End_Date__c ? new Date(this.selectedPass.End_Date__c).toLocaleDateString() : '';
    }
    get formattedPrice() {
        return this.selectedPass?.Season_Pass_Price__c ? `$${this.selectedPass.Season_Pass_Price__c.toFixed(2)}` : '';
    }
    get autoRenewText() {
        return this.selectedPass?.Auto_Renew__c ? 'Yes' : 'No';
    }
    get selectedPassTeamName() {
        return this.selectedPass?.Team__r?.Name || '';
    }
    get selectedPassSectionName() {
        return this.selectedPass?.Stadium_Section__r?.Name || '';
    }

    handlePassSelection(event) {
        const newId = event.detail.value;
        this.selectedPassId = newId;
        this.selectedPass = this.seasonPasses.find(p => p.Id === newId);
        if (this.selectedPass) {
            this.showDetails = true;
            this.showForm = false;
        }
    }

    handleEdit() {
        this.editingPassId = this.selectedPass.Id;
        this.teamId = this.selectedPass.Team__c;
        this.sectionId = this.selectedPass.Stadium_Section__c;
        this.showForm = true;
        this.showDetails = false;
    }

    handleNewPass() {
        if (!this.selectedFanId) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Select Fan',
                message: 'Please select a fan first.',
                variant: 'info'
            }));
            return;
        }
        this.editingPassId = null;
        this.teamId = null;
        this.sectionId = null;
        this.showForm = true;
        this.showDetails = false;
    }

    handleCancelForm() {
        if (this.seasonPasses.length > 0) {
            this.showDetails = true;
            this.showForm = false;
        } else {
            this.showForm = false;
            this.showDetails = false;
        }
    }

    handleSaveSuccess() {
        this.loadSeasonPasses();
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: 'Season pass saved successfully',
            variant: 'success'
        }));
    }

    handleSaveError(event) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error saving season pass',
            message: event.detail.message,
            variant: 'error'
        }));
    }

    handleTeamChange(event) {
        this.teamId = event.detail.value;
    }
}