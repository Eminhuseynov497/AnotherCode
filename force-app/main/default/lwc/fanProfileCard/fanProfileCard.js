import { LightningElement, api, wire, track } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getFanProfile from '@salesforce/apex/FanProfileCardController.getFanProfile';

export default class FanProfileCard extends LightningElement {
    _recordId;
    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        if (this._recordId !== value) {
            this._recordId   = value;
            this._resolvedId = value;
        }
    }

    @track _resolvedId;

    profile;

    @wire(CurrentPageReference)
    wiredPageRef(ref) {
        if (!ref) return;

        const fromAttr  = ref.attributes?.recordId;
        const fromState = ref.state?.recordId;
        const fromUrl   = new URLSearchParams(window.location.search).get('recordId');
        const fromPath  = this._extractIdFromPath();

        const resolved = this._recordId || fromAttr || fromState || fromUrl || fromPath;
        if (resolved && resolved !== this._resolvedId) {
            this._recordId   = resolved;
            this._resolvedId = resolved;
        }
    }

    connectedCallback() {
        if (this._resolvedId) return;
        const fromUrl  = new URLSearchParams(window.location.search).get('recordId');
        const fromPath = this._extractIdFromPath();
        const resolved = this._recordId || fromUrl || fromPath;
        if (resolved) {
            this._recordId   = resolved;
            this._resolvedId = resolved;
        }
    }

    _extractIdFromPath() {
        const segments = window.location.pathname.split('/').filter(Boolean);
        if (segments.length < 2) return null;
        const candidate = segments[segments.length - 2];
        if (candidate && /^[a-zA-Z0-9]{15,18}$/.test(candidate)) {
            return candidate;
        }
        return null;
    }

    @wire(getFanProfile, { fanId: '$_resolvedId' })
    wiredProfile({ error, data }) {
        if (data) {
            this.profile = data;
        } else if (error) {
            console.error('Error loading fan profile', error);
        }
    }
}