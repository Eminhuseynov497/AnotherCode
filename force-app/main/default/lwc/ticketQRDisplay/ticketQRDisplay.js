import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getTicketData from '@salesforce/apex/TicketQRController.getTicketData';

export default class TicketQRDisplay extends LightningElement {
    @api recordId;
    @track qrImageUrl;
    @track eventName = 'No data';
    @track seatLabel = 'No data';
    @track statusLabel = 'No data';
    @track statusVariant = 'inverse';
    @track eventDateTime = 'No data';
    @track stadiumName = 'No data';
    @track isGenerating = false;
    @track isLoading = true;

    connectedCallback() {
        this.findTicketId();
        if (this.recordId) {
            this.loadTicketData();
        } else {
            this.isLoading = false;
        }
    }

    findTicketId() {
        if (this.recordId) return;
        const fullUrl = window.location.href;
        const match = fullUrl.match(/a07[A-Za-z0-9]{15}/);
        if (match) {
            this.recordId = match[0];
            console.log('ID found:', this.recordId);
        }
    }

    loadTicketData() {
        this.isLoading = true;
        getTicketData({ ticketId: this.recordId })
            .then(result => {
                this.qrImageUrl = null;
                this.seatLabel = result.seatLabel || '—';
                this.statusLabel = this.getStatusLabel(result.status);
                this.statusVariant = this.getStatusVariant(result.status);
                this.eventName = result.eventName || '—';
                this.eventDateTime = this.formatDateTime(result.eventDateTime);
                this.stadiumName = result.stadiumName || '—';
                this.isLoading = false;
            })
            .catch(error => {
                this.isLoading = false;
                console.error('Download Error:', error);
            });
    }

    get showPlaceholder() {
        return !this.isLoading && !this.qrImageUrl && !this.isGenerating;
    }

    get isDownloadDisabled() {
        return !this.qrImageUrl;
    }

    async handleGenerateQR() {
        if (this.isGenerating || this.qrImageUrl || !this.recordId) return;

        this.isGenerating = true;

        const qrContent = this.recordId;
        const apiUrl = `https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${qrContent}`;

        try {
            const response = await fetch(apiUrl);
            if (!response.ok) throw new Error(`HTTP error ${response.status}`);
            
            const blob = await response.blob();
            const reader = new FileReader();
            reader.readAsDataURL(blob);
            reader.onloadend = () => {
                this.qrImageUrl = reader.result;
                this.isGenerating = false;
                console.log('QR code generated as Data URL');
            };
        } catch (error) {
            this.isGenerating = false;
            console.error('QR Generation Error:', error);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to generate QR code. Check trusted CSP sites.',
                    variant: 'error'
                })
            );
        }
    }

    handleDownload() {
        if (this.qrImageUrl) {
            const link = document.createElement('a');
            link.href = this.qrImageUrl;
            link.download = `QR_${this.recordId}.png`;
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
        }
    }

    handleShare() {
        if (this.qrImageUrl) {
            window.open(this.qrImageUrl, '_blank');
        }
    }

    getStatusLabel(status) {
        const map = {
            'Available': 'Available',
            'Reserved': 'Reserved',
            'Sold': 'Sold',
            'Cancelled': 'Cancelled',
            'Checked In': 'Checked In'
        };
        return map[status] || status;
    }

    getStatusVariant(status) {
        const map = {
            'Available': 'success',
            'Reserved': 'warning',
            'Sold': 'info',
            'Cancelled': 'inverse',
            'Checked In': 'success'
        };
        return map[status] || 'inverse';
    }

    formatDateTime(dateTimeString) {
        if (!dateTimeString) return '—';
        const date = new Date(dateTimeString);
        return date.toLocaleDateString('en-GB', {
            year: 'numeric',
            month: 'long',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });
    }
}