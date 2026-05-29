import { LightningElement, track, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import getFanBalance from '@salesforce/apex/RewardService.getFanBalance';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LOYALTY_POINTS_FIELD from '@salesforce/schema/Fan__c.Loyalty_Points_Balance__c';
import jerseyImage from '@salesforce/resourceUrl/teamjersey';
import vipImage from '@salesforce/resourceUrl/VIPLoungeAccess';
import ballImage from '@salesforce/resourceUrl/SignedBall';
import couponImage from '@salesforce/resourceUrl/DiscountCoupon';
import tourImage from '@salesforce/resourceUrl/StadiumTour';
import meetImage from '@salesforce/resourceUrl/MeetGreet';

const IMAGE_MAP = {
    '1': jerseyImage,
    '2': vipImage,
    '3': ballImage,
    '4': couponImage,
    '5': tourImage,
    '6': meetImage
};

const TEST_REWARDS = [
    { id: '1', Name: 'Team Jersey', Description__c: 'Official team jersey', Points_Cost__c: 500, Category__c: 'Merchandise', Stock_Quantity__c: 10 },
    { id: '2', Name: 'VIP Lounge Access', Description__c: 'VIP lounge pass for one game', Points_Cost__c: 2000, Category__c: 'VIP Access', Stock_Quantity__c: 5 },
    { id: '3', Name: 'Signed Ball', Description__c: 'Ball signed by the team captain', Points_Cost__c: 1500, Category__c: 'Souvenir', Stock_Quantity__c: 3 },
    { id: '4', Name: 'Discount Coupon', Description__c: '10% off next ticket purchase', Points_Cost__c: 300, Category__c: 'Other', Stock_Quantity__c: null },
    { id: '5', Name: 'Stadium Tour', Description__c: 'Behind-the-scenes tour for two', Points_Cost__c: 800, Category__c: 'Experience', Stock_Quantity__c: 4 },
    { id: '6', Name: 'Meet & Greet', Description__c: 'Photo and autograph session with players', Points_Cost__c: 3500, Category__c: 'Experience', Stock_Quantity__c: 1 }
];

export default class LoyaltyRewardStore extends LightningElement {
    @api recordId;
    @track rewards = [];
    @track loading = true;
    
    fanBalance = 0;

    @wire(getRecord, { recordId: '$recordId', fields: [LOYALTY_POINTS_FIELD] })
    fanRecord({ error, data }) {
        if (data) {
            const balance = getFieldValue(data, LOYALTY_POINTS_FIELD);
            this.fanBalance = balance != null ? Number(balance) : 0;
            console.log('LoyaltyRewardStore: Balance from wire service:', this.fanBalance);
            this.updateRewardAvailability();
            this.loading = false;
        } else if (error) {
            console.error('LoyaltyRewardStore: Wire service error:', error);
            this.fanBalance = 0;
            this.updateRewardAvailability();
            this.loading = false;
        }
    }

    connectedCallback() {
        console.log('LoyaltyRewardStore: connectedCallback - recordId:', this.recordId);
        
        this.rewards = TEST_REWARDS.map(reward => ({
            ...reward,
            Image_URL__c: IMAGE_MAP[reward.id] || '',
            isDisabled: true,
            disabledReason: 'Loading...'
        }));

        if (!this.recordId) {
            console.warn('LoyaltyRewardStore: No recordId provided');
            this.loading = false;
            this.fanBalance = 0;
            this.updateRewardAvailability();
        }
    }

    updateRewardAvailability() {
        console.log('LoyaltyRewardStore: Updating reward availability. Balance:', this.fanBalance);

        this.rewards = this.rewards.map(reward => {
            const outOfStock = reward.Stock_Quantity__c !== null && reward.Stock_Quantity__c <= 0;
            const insufficientPoints = this.fanBalance < reward.Points_Cost__c;
            const isDisabled = insufficientPoints || outOfStock;

            let disabledReason = '';
            if (insufficientPoints) {
                disabledReason = `Need ${reward.Points_Cost__c} points (you have ${this.fanBalance})`;
            } else if (outOfStock) {
                disabledReason = 'Out of stock';
            }

            console.log(`Reward: ${reward.Name}, Cost: ${reward.Points_Cost__c}, Balance: ${this.fanBalance}, Disabled: ${isDisabled}, Reason: ${disabledReason}`);

            return { ...reward, isDisabled, disabledReason };
        });
    }

    handleBuy(event) {
        const rewardName = event.target.dataset.name;
        const cost = parseInt(event.target.dataset.cost, 10);

        if (this.fanBalance < cost) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Insufficient Points',
                message: `Need ${cost} points, you have ${this.fanBalance}.`,
                variant: 'error'
            }));
            return;
        }

        this.dispatchEvent(new ShowToastEvent({
            title: 'Soon',
            message: `Reward "${rewardName}" will be available soon.`,
            variant: 'info'
        }));
    }
}