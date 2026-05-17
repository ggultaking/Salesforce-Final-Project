import { LightningElement, wire, api, track } from 'lwc';
import getTopMatches from '@salesforce/apex/PropertyMatchController.getTopMatches';
import markNotInterested from '@salesforce/apex/PropertyMatchController.markNotInterested';
import scheduleShowing from '@salesforce/apex/PropertyMatchController.scheduleShowing';
import { refreshApex } from '@salesforce/apex';

export default class PropertyMatchBoard extends LightningElement {

    @api recordId; // BUYER ID (CRITICAL)
    @track matches = [];

    minPrice;
    maxPrice;
    minScore;
    hotOnly = false;

    wiredResult;

    @wire(getTopMatches, {
        buyerId: '$recordId',
        minPrice: '$minPrice',
        maxPrice: '$maxPrice',
        minScore: '$minScore',
        hotOnly: '$hotOnly'
    })
    wiredData(result) {
        this.wiredResult = result;

        if (result.data) {
            this.matches = result.data.map(item => ({
                ...item,
                borderClass: this.getBorder(item.interestLevel)
            }));
        }
    }

    handleMinPrice(e) { this.minPrice = e.target.value; }
    handleMaxPrice(e) { this.maxPrice = e.target.value; }
    handleMinScore(e) { this.minScore = e.target.value; }
    handleHotOnly(e) { this.hotOnly = e.target.checked; }

    handleRefresh() {
        refreshApex(this.wiredResult);
    }

    markNotInterested(event) {
        markNotInterested({ propertyMatchId: event.target.dataset.id })
            .then(() => refreshApex(this.wiredResult));
    }

    openMap(event) {
        const item = this.matches.find(x => x.propertyId === event.target.dataset.id);
        window.open(`https://www.google.com/maps?q=${item.address}`);
    }

    openSchedule(event) {
        // modal later
    }

    getBorder(level) {
        if (level === 'Hot') return 'hot-border';
        if (level === 'Warm') return 'warm-border';
        return 'cold-border';
    }
}