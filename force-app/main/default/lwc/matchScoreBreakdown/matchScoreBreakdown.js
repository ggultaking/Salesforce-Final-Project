import { LightningElement, wire, track, api } from 'lwc';
import getTopMatches from '@salesforce/apex/PropertyMatchController.getTopMatches';
import markNotInterested from '@salesforce/apex/PropertyMatchController.markNotInterested';
import { refreshApex } from '@salesforce/apex';

export default class MatchScoreBreakdown extends LightningElement {

    @api recordId;

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
    wiredMatches(result) {
        this.wiredResult = result;

        if (result.data) {
            this.matches = result.data.map(item => ({
                ...item,
                borderClass: this.getBorderClass(item.interestLevel)
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
        const item = this.matches.find(m => m.propertyId === event.target.dataset.id);
        if (item?.address) {
            window.open(`https://www.google.com/maps?q=${item.address}`, '_blank');
        }
    }

    openSchedule() {
        // modal phase later
    }

    getBorderClass(level) {
        if (level === 'Hot') return 'hot-border';
        if (level === 'Warm') return 'warm-border';
        return 'cold-border';
    }
}