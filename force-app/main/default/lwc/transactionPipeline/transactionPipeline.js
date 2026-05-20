import { LightningElement, track } from 'lwc';
import getPipeline from '@salesforce/apex/TransactionService.getPipeline';
import advanceStage from '@salesforce/apex/TransactionService.advanceStage';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
export default class TransactionPipeline extends LightningElement {

    @track transactions = [];
    @track groupedList = [];
    @track selectedTransaction;

    // filters
    searchKey = '';

    connectedCallback() {
       this.loadPipeline();

    this.refreshInterval = setInterval(() => {
        this.loadPipeline();
    }, 30000);
    }
    disconnectedCallback() {
    clearInterval(this.refreshInterval);
}

    // ======================
    // LOAD DATA
    // ======================
    loadPipeline() {
        getPipeline()
            .then(data => {
                this.transactions = data;
                this.prepareData();
            })
            .catch(err => console.error(err));
    }

    // ======================
    // SAFE GROUPING (NO LWC ERRORS)
    // ======================
    prepareData() {

        const map = {};

        this.transactions.forEach(t => {

            const stage = t.Status__c || 'Unknown';

            if (!map[stage]) {
                map[stage] = [];
            }

            map[stage].push({
                ...t,

                // UI helper fields
                cardClass: this.getCardClass(t),
                daysLeft: this.calculateDaysLeft(t)
            });
        });

        // convert to array (LWC SAFE)
        this.groupedList = Object.keys(map).map(stage => {
            return {
                stage: stage,
                items: map[stage]
            };
        });
    }

    // ======================
    // FIX: CSS CLASS SAFE
    // ======================
    getCardClass(t) {
        const urgency = t.urgency || 'green';
        return `card ${urgency}`;
    }

    // ======================
    // DAYS LEFT
    // ======================
    calculateDaysLeft(t) {
        if (!t.Est_Closing_Date__c) return 0;

        const today = new Date();
        const closing = new Date(t.Est_Closing_Date__c);

        return Math.ceil((closing - today) / (1000 * 60 * 60 * 24));
    }

    // ======================
    // FILTER (SAFE)
    // ======================
    handleSearch(event) {
        this.searchKey = event.target.value?.toLowerCase() || '';

        if (!this.searchKey) {
            this.prepareData();
            return;
        }

        const filtered = this.transactions.filter(t =>
            (t.Property__r?.Address__c || '').toLowerCase()
                .includes(this.searchKey)
        );

        this.transactions = filtered;
        this.prepareData();
    }

    // ======================
    // SIDE PANEL
    // ======================
    openDetails(event) {
        const id = event.currentTarget.dataset.id;
        this.selectedTransaction =
            this.transactions.find(t => t.Id === id);
    }

    closePanel() {
        this.selectedTransaction = null;
    }

    allowDrop(event) {
        event.preventDefault();
    }

    dragStart(event) {
        event.dataTransfer.setData("id", event.target.dataset.id);
    }

    drop(event) {
    event.preventDefault();

    const transactionId = event.dataTransfer.getData("id");
    const newStatus = event.currentTarget.dataset.stage;

    advanceStage({
        transactionId: transactionId,
        newStatus: newStatus
    })
    .then(() => {
        this.loadPipeline();

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: 'Stage updated',
                variant: 'success'
            })
        );
    })
    .catch(err => {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: err.body?.message || err.message,
                variant: 'error'
            })
        );
    });
}
}