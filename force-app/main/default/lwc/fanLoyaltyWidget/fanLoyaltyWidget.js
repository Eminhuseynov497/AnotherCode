import { LightningElement, api, track } from 'lwc';
import getFanData from '@salesforce/apex/FanProfileController.getFanData';
import getFanForCurrentUser from '@salesforce/apex/FanProfileController.getFanForCurrentUser';

const TIER_THRESHOLDS = {
    'Bronze': 0,
    'Silver': 500,
    'Gold': 2000,
    'Platinum': 5000
};

export default class FanLoyaltyWidget extends LightningElement {
    @api recordId;
    @api fanId;
    @api seasonPassId;
    @track fan = {};
    @track futureEventsCount = 0;
    @track recentOrders = [];
    @track loyaltyTransactions = [];
    @track activeSeasonPasses = [];
    @track error;
    @track loading = false;

    connectedCallback() {
        this.loading = true;
        this.loadFanData();
    }

    async loadFanData() {
        try {
            let fanId = this.fanId || this.recordId || this.seasonPassId;

            if (!fanId) {
                const fan = await getFanForCurrentUser();
                if (fan) {
                    fanId = fan.Id;
                    this.fan = fan;
                } else {
                    this.fan = {
                        Id: 'demo',
                        Name: 'Demo Fan',
                        Loyalty_Tier__c: 'Gold',
                        Loyalty_Points_Balance__c: 2500,
                        Lifetime_Points__c: 2500,
                        Total_Spend__c: 5000,
                        Registration_Date__c: '2024-01-01'
                    };
                    this.futureEventsCount = 3;
                    this.recentOrders = [
                        { Id: '1', Order_Number__c: 'ORD-001', Total_Amount__c: 150, Status__c: 'Confirmed' },
                        { Id: '2', Order_Number__c: 'ORD-002', Total_Amount__c: 200, Status__c: 'Confirmed' }
                    ];
                    this.loyaltyTransactions = [
                        { Id: '1', Type__c: 'Earned', Points__c: 100, Reason__c: 'Purchase' },
                        { Id: '2', Type__c: 'Earned', Points__c: 50, Reason__c: 'Attendance' }
                    ];
                    this.activeSeasonPasses = [
                        { Id: '1', Team__r: { Name: 'Manchester United' }, Season__c: '2025', Payment_Plan__c: 'Full' }
                    ];
                    this.error = undefined;
                    this.loading = false;
                    return;
                }
            }

            if (fanId) {
                const data = await getFanData({ fanId: fanId });
                this.fan = data.fan || {};
                this.futureEventsCount = data.futureEventsCount || 0;
                this.recentOrders = data.recentOrders || [];
                this.loyaltyTransactions = data.loyaltyTransactions || [];
                this.activeSeasonPasses = data.activeSeasonPasses || [];
                this.error = undefined;
            }
        } catch (error) {
            this.error = error.message || 'Failed to load fan data';
            this.fan = {};
            this.futureEventsCount = 0;
            this.recentOrders = [];
            this.loyaltyTransactions = [];
            this.activeSeasonPasses = [];
        } finally {
            this.loading = false;
        }
    }

    

    renderedCallback() {
        const fill = this.template.querySelector('[data-element-id="progressFill"]');
        if (fill) {
            fill.style.width = this.progressPercent + '%';
        }
    }
    get tierClass() {
        return this.fan.Loyalty_Tier__c ? this.fan.Loyalty_Tier__c.toLowerCase() : 'bronze';
    }

    get memberSince() {
        if (!this.fan.Registration_Date__c) return 'N/A';
        const date = new Date(this.fan.Registration_Date__c);
        return date.toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' });
    }

    get eventsCount() {
        return this.futureEventsCount || 0;
    }

    get progressPercent() {
        if (!this.fan.Loyalty_Tier__c || this.fan.Lifetime_Points__c === undefined) return 0;
        const currentTier = this.fan.Loyalty_Tier__c;
        if (currentTier === 'Platinum') return 100;
        const currentThreshold = TIER_THRESHOLDS[currentTier];
        const nextTier = this.getNextTier(currentTier);
        if (!nextTier) return 100;
        const nextThreshold = TIER_THRESHOLDS[nextTier];
        const points = this.fan.Lifetime_Points__c || 0;
        const progress = ((points - currentThreshold) / (nextThreshold - currentThreshold)) * 100;
        return Math.min(Math.max(progress, 0), 100);
    }

    get nextTierName() {
        if (!this.fan.Loyalty_Tier__c) return 'Platinum';
        return this.getNextTier(this.fan.Loyalty_Tier__c) || 'Platinum';
    }

    get pointsToNext() {
        if (!this.fan.Loyalty_Tier__c || this.fan.Lifetime_Points__c === undefined) return 0;
        const currentTier = this.fan.Loyalty_Tier__c;
        if (currentTier === 'Platinum') return 0;
        const nextTier = this.getNextTier(currentTier);
        if (!nextTier) return 0;
        const nextThreshold = TIER_THRESHOLDS[nextTier];
        const points = this.fan.Lifetime_Points__c || 0;
        return Math.max(nextThreshold - points, 0);
    }
    
    getNextTier(currentTier) {
        const tiers = ['Bronze', 'Silver', 'Gold', 'Platinum'];
        const index = tiers.indexOf(currentTier);
        return (index >= 0 && index < tiers.length - 1) ? tiers[index + 1] : null;
    }
}