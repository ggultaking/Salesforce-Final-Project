import { LightningElement, wire, api, track } from 'lwc';
import getTopMatches from '@salesforce/apex/PropertyMatchController.getTopMatches';
import markNotInterested from '@salesforce/apex/PropertyMatchController.markNotInterested';
import scheduleShowing from '@salesforce/apex/PropertyMatchController.scheduleShowing';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class PropertyMatchBoard extends LightningElement {

    @api recordId;

    @track matches = [];
    wiredResult;

    minPrice;
    maxPrice;
    minScore;
    hotOnly = false;

    isLoading = false;

    // =========================
    // WIRED
    // =========================
    @wire(getTopMatches, {
        buyerId: '$recordId',
        minPrice: '$minPrice',
        maxPrice: '$maxPrice',
        minScore: '$minScore',
        hotOnly: '$hotOnly'
    })
    wiredMatches(result) {
        this.wiredResult = result;

        if (result.data) {
            this.matches = result.data.map(x => ({
                ...x,
                borderClass: this.getBorder(x.interestLevel),

                // fallback image
                imageUrl: x.photoUrl || '/img/sample-property.jpg',
                 viewedCount: x.viewedCount ? x.viewedCount : 0
            }));
        }
    }

    // =========================
    // FILTERS
    // =========================
    handleMinPrice(e) { this.minPrice = e.target.value; }
    handleMaxPrice(e) { this.maxPrice = e.target.value; }
    handleMinScore(e) { this.minScore = e.target.value; }
    handleHotOnly(e) { this.hotOnly = e.target.checked; }

    // =========================
    // REFRESH
    // =========================
    handleRefresh() {
        this.isLoading = true;

        refreshApex(this.wiredResult)
            .then(() => {
                this.toast('Success', 'Matches refreshed', 'success');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // =========================
    // GAP 8 — GOOGLE MAPS FIXED UX
    // =========================
    openMap(event) {
        const item = this.matches.find(x => x.propertyId === event.target.dataset.id);

        if (item?.address) {
            const encoded = encodeURIComponent(item.address);

            window.open(
                `https://www.google.com/maps/search/?api=1&query=${encoded}`,
                '_blank'
            );
        }
    }

    // =========================
    // GAP 9 — MODAL TRIGGER
    // =========================
    selectedPropertyId;
    showScheduleModal = false;

openSchedule(event) {
    const id = event.target.dataset.id;

    this.matches = this.matches.map(m => {
        if (m.propertyId === id) {
            return {
                ...m,
                viewedCount: (m.viewedCount || 0) + 1
            };
        }
        return m;
    });

    this.selectedPropertyId = id;
    this.showScheduleModal = true;
}

    closeModal() {
        this.showScheduleModal = false;
        this.selectedPropertyId = null;
    }

    handleDateChange(event) {
        this.selectedDate = event.target.value;
    }

    saveSchedule() {

        if (!this.selectedDate) {
            this.toast('Error', 'Please select date/time', 'error');
            return;
        }

        scheduleShowing({
            propertyId: this.selectedPropertyId,
            buyerId: this.recordId,
            showingDate: new Date(this.selectedDate),
            durationMinutes: 30
        }).then(() => {
            this.toast('Success', 'Showing scheduled', 'success');
            this.closeModal();
        });
    }

    // =========================
    // NOT INTERESTED
    // =========================
    markNotInterested(event) {
        const id = event.target.dataset.id;

        markNotInterested({ propertyMatchId: id })
            .then(() => {
                this.toast('Updated', 'Not interested marked', 'success');
                return refreshApex(this.wiredResult);
            });
    }

    // =========================
    // BORDER LOGIC
    // =========================
    getBorder(level) {
        if (level === 'Hot') return 'hot-border';
        if (level === 'Warm') return 'warm-border';
        return 'cold-border';
    }

    // =========================
    // TOAST
    // =========================
    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant
        }));
    }
}