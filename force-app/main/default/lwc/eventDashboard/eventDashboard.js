import { LightningElement, api, wire } from 'lwc';
import getDashboardData from '@salesforce/apex/EventDashboardController.getDashboardData';

export default class EventDashboard extends LightningElement {
    @api recordId;

    totalTickets = 0;
    ticketsSold = 0;
    occupancyPercent = 0;
    totalRevenue = 0;
    sectionOccupancy = [];
    recentOrders = [];

    @wire(getDashboardData, { eventId: '$recordId' })
    wiredData({ error, data }) {
        if (data) {
            this.totalTickets = data.totalTickets;
            this.ticketsSold = data.ticketsSold;
            this.occupancyPercent = data.occupancyPercent;
            this.totalRevenue = data.totalRevenue;
            this.sectionOccupancy = data.sectionOccupancy.map(sec => ({
                ...sec,
                percent: sec.percent
            }));
            this.recentOrders = data.recentOrders.map(order => ({
                ...order,
                orderDate: order.orderDate ? new Date(order.orderDate).toLocaleString() : ''
            }));
        } else if (error) {
            console.error('Error loading dashboard', error);
        }
    }

    handleRefresh() {
        getDashboardData({ eventId: this.recordId })
            .then(data => {
                this.wiredData({ data });
            })
            .catch(error => {
                console.error(error);
            });
    }
}