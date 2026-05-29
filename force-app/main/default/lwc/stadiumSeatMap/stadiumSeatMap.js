import { LightningElement, api, track, wire } from 'lwc';
import getEventSections from '@salesforce/apex/StadiumSeatMapController.getEventSections';
import getSeatsForSection from '@salesforce/apex/StadiumSeatMapController.getSeatsForSection';
import reserveSelectedSeats from '@salesforce/apex/StadiumSeatMapController.reserveSelectedSeats';
import releaseReservation from '@salesforce/apex/StadiumSeatMapController.releaseReservation';
import { CurrentPageReference } from 'lightning/navigation';

export default class StadiumSeatMap extends LightningElement {
    _recordId;
    @track sections = [];
    @track selectedSectionId = null;
    @track selectedSectionName = '';
    @track seatsByRow = [];
    @track cartSeats = [];
    @track isReserved = false;
    @track reservationEndTime = null;
    @track loading = false;
    @track errorMessage = '';

    reservationTimer = null;
    _selectedTicketIds = [];
    _sectionsLoaded = false;

    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        if (this._recordId !== value) {
            this._recordId = value;
            this.resetComponent();
            if (this._recordId) {
                this._sectionsLoaded = false;
                this.loadSections();
            }
        }
    }

    @api
    getSelectedTicketIds() {
        return this.cartSeats.map(s => s.ticketId);
    }

    @api
    getReservationUntil() {
        return this.reservationEndTime;
    }

    @api
    clearReservation() {
        this.isReserved = false;
        this.reservationEndTime = null;
        clearInterval(this.reservationTimer);
        this.cartSeats = [];
        if (this.selectedSectionId) {
            this.loadSeats(this.selectedSectionId);
        }
    }

    @wire(CurrentPageReference)
    wiredPageRef(ref) {
        if (!ref) return;

        const fromAttr  = ref.attributes?.recordId;
        const fromState = ref.state?.recordId;
        const fromUrl   = new URLSearchParams(window.location.search).get('recordId');
        const fromPath  = this._extractIdFromPath();

        const resolved = this._recordId || fromAttr || fromState || fromUrl || fromPath;

        if (resolved && resolved !== this._recordId) {
            this._recordId = resolved;
            this.resetComponent();
            this._sectionsLoaded = false;
            this.loadSections();
        } else if (!resolved && !this._sectionsLoaded) {
            this.errorMessage =
                'ID события не найден. Передайте recordId через URL-параметр (?recordId=ID) ' +
                'или добавьте компонент на Record Page объекта Sport_Event__c.';
        }
    }

    connectedCallback() {
        if (this._recordId) {
            if (!this._sectionsLoaded) {
                this.loadSections();
            }
            return;
        }

        const fromUrl  = new URLSearchParams(window.location.search).get('recordId');
        const fromPath = this._extractIdFromPath();
        const resolved = fromUrl || fromPath;

        if (resolved) {
            this._recordId = resolved;
            this._sectionsLoaded = false;
            this.loadSections();
        }
    }

    disconnectedCallback() {
        clearInterval(this.reservationTimer);
    }

_extractIdFromPath() {
    const segments = window.location.pathname.split('/');
    for (let i = segments.length - 1; i >= 0; i--) {
        const seg = segments[i];
        if (seg && /^[a-zA-Z0-9]{15,18}$/.test(seg)) {
            return seg;
        }
    }
    return null;
}

    resetComponent() {
        clearInterval(this.reservationTimer);
        this.isReserved = false;
        this.reservationEndTime = null;
        this.cartSeats = [];
        this.selectedSectionId = null;
        this.selectedSectionName = '';
        this.seatsByRow = [];
        this.sections = [];
        this.errorMessage = '';
        this._sectionsLoaded = false;
    }

    async loadSections() {
        if (!this._recordId) {
            this.errorMessage = 'Event ID is missing.';
            return;
        }
        this.loading = true;
        this.errorMessage = '';
        try {
            const rawSections = await getEventSections({ eventId: this._recordId });
            this.sections = rawSections.map(section => ({
                ...section,
                formattedStartingPrice: this.formatCurrency(section.startingPrice)
            }));
            this._sectionsLoaded = true;
            if (!this.sections.length) {
                this.errorMessage = 'No sections available for this event.';
            }
        } catch (error) {
            this.errorMessage = 'Error loading sections. Please refresh.';
            console.error('loadSections error:', error);
        } finally {
            this.loading = false;
        }
    }

    handleSectionClick(event) {
        const sectionId = event.currentTarget.dataset.id;
        if (!sectionId) return;
        this.selectedSectionId = sectionId;
        const section = this.sections.find(s => s.sectionId === sectionId);
        this.selectedSectionName = section ? section.name : '';
        this.loadSeats(sectionId);
    }

    async loadSeats(sectionId) {
        if (!sectionId) return;
        this.loading = true;
        this.errorMessage = '';
        try {
            const seats = await getSeatsForSection({ eventId: this._recordId, sectionId });
            const selectedIds = this.cartSeats.map(s => s.ticketId);
            const seatsWithFormat = seats.map(seat => {
                const isSelected = selectedIds.includes(seat.ticketId);
                return {
                    ...seat,
                    formattedPrice: this.formatCurrency(seat.dynamicPrice),
                    cssClass: this.computeSeatClass(seat, isSelected)
                };
            });
            const rowsMap = {};
            seatsWithFormat.forEach(seat => {
                if (!rowsMap[seat.row]) rowsMap[seat.row] = [];
                rowsMap[seat.row].push(seat);
            });
            this.seatsByRow = Object.keys(rowsMap)
                .sort((a, b) => parseInt(a, 10) - parseInt(b, 10))
                .map(row => ({
                    row: parseInt(row, 10),
                    seats: rowsMap[row]
                }));
        } catch (error) {
            this.errorMessage = 'Error loading seats. Please try again.';
            console.error('loadSeats error:', error);
        } finally {
            this.loading = false;
        }
    }

    computeSeatClass(seat, isSelected) {
        if (isSelected) return 'seat selected';
        return 'seat ' + (seat.status || '').toLowerCase().replace(' ', '-');
    }

    handleSeatClick(event) {
        const ticketId = event.currentTarget.dataset.id;
        const seat = this.findSeatById(ticketId);
        if (!seat || seat.status !== 'Available' || this.cartSeats.length >= 6) return;
        if (!this.cartSeats.find(c => c.ticketId === ticketId)) {
            this.cartSeats = [...this.cartSeats, seat];
            this.updateSeatSelection();
        }
    }

    handleSeatDblClick(event) {
        this.removeFromCart(event);
    }

    removeFromCart(event) {
        const ticketId = event.currentTarget.dataset.id;
        this.cartSeats = this.cartSeats.filter(c => c.ticketId !== ticketId);
        this.updateSeatSelection();
    }

    updateSeatSelection() {
        const selectedIds = this.cartSeats.map(s => s.ticketId);
        this.seatsByRow = this.seatsByRow.map(rowObj => ({
            ...rowObj,
            seats: rowObj.seats.map(s => ({
                ...s,
                cssClass: this.computeSeatClass(s, selectedIds.includes(s.ticketId))
            }))
        }));
    }

    formatCurrency(value) {
        if (!value && value !== 0) return '$0.00';
        return '$' + value.toFixed(2);
    }

    get totalPrice() {
        return this.cartSeats.reduce((sum, s) => sum + (s.dynamicPrice || 0), 0);
    }

    get formattedTotalPrice() {
        return this.formatCurrency(this.totalPrice);
    }

    get canReserve() {
        return this.cartSeats.length > 0 && !this.isReserved;
    }

    get reserveDisabled() {
        return !this.canReserve;
    }

    async handleReserve() {
        if (!this.canReserve) return;
        this.loading = true;
        this.errorMessage = '';
        try {
            const ids = this.cartSeats.map(s => s.ticketId);
            const holdUntilStr = await reserveSelectedSeats({ ticketIds: ids });
            this.isReserved = true;
            this.reservationEndTime = holdUntilStr;
            this.startCountdown(new Date(holdUntilStr));
            this._selectedTicketIds = ids;
            this.dispatchEvent(new CustomEvent('reservationcomplete', {
                detail: { ticketIds: ids, reservationUntil: holdUntilStr }
            }));
        } catch (error) {
            this.errorMessage = 'Reservation failed: ' + (error.body?.message || error.message);
            console.error('handleReserve error:', error);
        } finally {
            this.loading = false;
        }
    }

    startCountdown(endDate) {
        clearInterval(this.reservationTimer);
        this.reservationTimer = setInterval(() => {
            const now = new Date();
            const diff = endDate - now;
            if (diff <= 0) {
                clearInterval(this.reservationTimer);
                this.isReserved = false;
                this.reservationEndTime = null;
                if (this.cartSeats.length) {
                    releaseReservation({ ticketIds: this.cartSeats.map(s => s.ticketId) })
                        .catch(e => console.warn('Release error:', e));
                }
                this.cartSeats = [];
                if (this.selectedSectionId) {
                    this.loadSeats(this.selectedSectionId);
                }
            } else {
                const mins = Math.floor(diff / 60000);
                const secs = Math.floor((diff % 60000) / 1000);
                this.reservationEndTime = `${mins}:${secs < 10 ? '0' : ''}${secs}`;
            }
        }, 1000);
    }

    async handleRefresh() {
        this.loading = true;
        this.errorMessage = '';
        try {
            if (this.selectedSectionId) {
                await this.loadSeats(this.selectedSectionId);
            }
            await this.loadSections();
        } catch (error) {
            this.errorMessage = 'Refresh error. Please try again.';
            console.error('handleRefresh error:', error);
        } finally {
            this.loading = false;
        }
    }

    findSeatById(ticketId) {
        for (const rowObj of this.seatsByRow) {
            const found = rowObj.seats.find(s => s.ticketId === ticketId);
            if (found) return found;
        }
        return null;
    }
}