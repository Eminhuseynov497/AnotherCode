import { LightningElement, api } from 'lwc';

export default class Clock extends LightningElement {
    timestamp = new Date();
    intervalId;

    connectedCallback() {
        this.intervalId = setInterval(() => {
            this.timestamp = new Date();
        }, 1000);
    }

    disconnectedCallback() {
        if (this.intervalId) {
            clearInterval(this.intervalId);
        }
    }

    @api
    refresh() {
        this.timestamp = new Date();
    }
}