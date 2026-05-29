import { LightningElement, track } from 'lwc';

export default class TeamSocialLinks extends LightningElement {
    @track instagramUrl = 'https://www.instagram.com/fifa/';
    @track twitterUrl = 'https://x.com/FIFAcom';
    @track facebookUrl = 'https://www.facebook.com/fifa/';
    @track linkedinUrl = 'https://www.linkedin.com/company/fifa/';

    get hasNoLinks() {
        return !this.instagramUrl && !this.twitterUrl && !this.facebookUrl && !this.linkedinUrl;
    }
}