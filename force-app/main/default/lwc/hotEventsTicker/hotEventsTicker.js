import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getHotEvents from '@salesforce/apex/HotEventsController.getHotEvents';

export default class HotEventsTicker extends NavigationMixin(LightningElement) {
    @track events = [];
    @track displayEvents = [];

    @wire(getHotEvents)
    wiredEvents({ error, data }) {
        if (data) {
            this.events = data.map(event => ({
                ...event,
                formattedDate: this.formatDate(event.Date_Time__c)
            }));
            // Создаём дублированный массив с уникальными ключами
            this.displayEvents = this.events.map((event, index) => ({
                ...event,
                uniqueKey: event.Id + '-' + index
            }));
            // Добавляем копию с другими уникальными ключами
            this.displayEvents = [
                ...this.displayEvents,
                ...this.events.map((event, index) => ({
                    ...event,
                    uniqueKey: event.Id + '-copy-' + index
                }))
            ];
        } else if (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to load hot events.',
                    variant: 'error'
                })
            );
        }
    }

    formatDate(dateStr) {
        if (!dateStr) return '';
        const date = new Date(dateStr);
        return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
    }

    handleBuy(event) {
        const eventId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: eventId,
                objectApiName: 'Sport_Event__c',
                actionName: 'view'
            }
        });
    }
}