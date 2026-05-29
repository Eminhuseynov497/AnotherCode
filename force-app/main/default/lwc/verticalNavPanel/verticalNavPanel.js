import { LightningElement, track, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class VerticalNavPanel extends NavigationMixin(LightningElement) {
    objects = [
        { apiName: 'Sport__c', label: 'Sport' },
        { apiName: 'League__c', label: 'League' },
        { apiName: 'Team__c', label: 'Team' },
        { apiName: 'Stadium__c', label: 'Stadium' },
        { apiName: 'Stadium_Section__c', label: 'Stadium Section' },
        { apiName: 'Sport_Event__c', label: 'Sport Event' },
        { apiName: 'Ticket__c', label: 'Ticket' },
        { apiName: 'Purchase_Order__c', label: 'Purchase Order' },
        { apiName: 'Fan__c', label: 'Fan' },
        { apiName: 'Season_Pass__c', label: 'Season Pass' },
        { apiName: 'Loyalty_Transaction__c', label: 'Loyalty Transaction' }
    ];

    @track isOpen = false;
    @api openByDefault = false;

    get panelClass() {
        return (this.isOpen ? 'panel open' : 'panel');
    }

    connectedCallback() {
        if (this.openByDefault) {
            this.isOpen = true;
        }
    }

    togglePanel() {
        this.isOpen = !this.isOpen;
    }

    closePanel() {
        this.isOpen = false;
    }

    navigateToObject(event) {
        const apiName = event.currentTarget.dataset.apiName;
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: apiName,
                actionName: 'home'
            }
        });
        this.closePanel();
    }
}