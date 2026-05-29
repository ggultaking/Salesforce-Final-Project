import { LightningElement, track, wire } from 'lwc';
import getPipeline           from '@salesforce/apex/TransactionService.getPipeline';
import advanceStage          from '@salesforce/apex/TransactionService.advanceStage';
import getTotalPipelineValue from '@salesforce/apex/TransactionService.getTotalPipelineValue';
import getTotalCommission    from '@salesforce/apex/TransactionService.getTotalCommission';
import { ShowToastEvent }    from 'lightning/platformShowToastEvent';
import { refreshApex }       from '@salesforce/apex';

const STAGES = ['Pipeline','Under Contract','Inspection','Appraisal','Closing','Closed'];

const HEADER_CLASS = {
    'Pipeline'      : 'col-header col-header--pipeline',
    'Under Contract': 'col-header col-header--contract',
    'Inspection'    : 'col-header col-header--inspection',
    'Appraisal'     : 'col-header col-header--appraisal',
    'Closing'       : 'col-header col-header--closing',
    'Closed'        : 'col-header col-header--closed'
};

// ── Currency formatter — ₼ (AZN) ─────────────────
function fmtAZN(v) {
    if (v == null || isNaN(v)) return '—';
    return new Intl.NumberFormat('az-AZ', {
        style              : 'currency',
        currency           : 'AZN',
        minimumFractionDigits: 0,
        maximumFractionDigits: 0
    }).format(v);
}

export default class TransactionPipeline extends LightningElement {

    @track transactions        = [];
    @track groupedList         = [];
    @track selectedTransaction = null;
    @track stageSteps          = [];
    @track isLoading           = false;
    @track pipelineValue       = 0;
    @track commission          = 0;
    @track agentOptions        = [];   // empty = hide filter

    searchKey     = '';
    selectedAgent = '';
    closeDateFrom = '';
    closeDateTo   = '';
    minPrice      = null;
    maxPrice      = null;

    _wiredResult;
    _refreshTimer;

    // ── Computed ─────────────────────────────────
    get pipelineValueFormatted() { return fmtAZN(this.pipelineValue); }
    get commissionFormatted()    { return fmtAZN(this.commission); }
    get activeDealCount()        { return this.transactions.filter(t => t.Status__c !== 'Closed').length; }

    /**
     * Show the agent filter only when there are real agent options
     * (i.e. at least one agent record was found in the data).
     */
    get showAgentFilter() { return this.agentOptions.length > 1; }

    // ── @wire ────────────────────────────────────
    @wire(getPipeline)
    wiredPipeline(result) {
        this._wiredResult = result;
        if (result.data) {
            this.transactions = result.data;
            this._buildAgentOptions(result.data);
            this.prepareData();
        } else if (result.error) {
            this._toast('Xəta', result.error.body?.message || 'Məlumat yüklənmədi', 'error');
        }
    }

    @wire(getTotalPipelineValue)
    wiredPV({ data }) { if (data != null) this.pipelineValue = data; }

    @wire(getTotalCommission)
    wiredComm({ data }) { if (data != null) this.commission = data; }

    // ── Lifecycle ────────────────────────────────
    connectedCallback() {
        this._refreshTimer = setInterval(() => {
            refreshApex(this._wiredResult);
        }, 30000);
    }

    disconnectedCallback() {
        clearInterval(this._refreshTimer);
    }

    // ── Data Prep ────────────────────────────────
    prepareData() {
        const filtered = this._applyFilters(this.transactions);
        const map = {};
        STAGES.forEach(s => { map[s] = []; });
        filtered.forEach(t => {
            const s = t.Status__c || 'Pipeline';
            if (map[s]) map[s].push(this._decorate(t));
        });
        this.groupedList = STAGES.map(stage => {
            const items = map[stage] || [];
            const total = items.reduce((sum, i) => sum + (i.Sale_Price__c || 0), 0);
            return {
                stage,
                items,
                count         : items.length,
                isEmpty       : items.length === 0,
                totalFormatted: fmtAZN(total),
                headerClass   : HEADER_CLASS[stage] || 'col-header'
            };
        });
    }

    _decorate(t) {
        const urgency    = this._urgency(t);
        const commission = (t.Sale_Price__c || 0) * 0.06;
        return {
            ...t,
            cardClass                    : 'card',
            urgencyStripe                : `urgency-stripe urgency-stripe--${urgency}`,
            urgencyBadgeClass            : `urgency-badge urgency-badge--${urgency}`,
            daysLeftLabel                : this._daysLeft(t) !== null ? `${this._daysLeft(t)}g qaldı` : '—',
            salePriceFormatted           : fmtAZN(t.Sale_Price__c),
            commissionFormatted          : fmtAZN(commission),
            listingCommissionFormatted   : fmtAZN(commission / 2),
            buyingCommissionFormatted    : fmtAZN(commission / 2),
            totalCommissionFormatted     : fmtAZN(commission),
            estClosingFormatted          : this._fmtDate(t.Est_Closing_Date__c),
            daysInStage                  : this._daysInStage(t),
            stageDurationLabel           : `${this._daysInStage(t)} gün (ort: 14)`,
            nextStageLabel               : this._nextLabel(t),
            isClosed                     : t.Status__c === 'Closed',
            buyerInitials                : this._initials(t.Buyer__r?.Name),
            listingAgentInitials         : this._initials(t.Listing_Agent__r?.Name),
            buyingAgentInitials          : this._initials(t.Buying_Agent__r?.Name),
            statusBadgeClass             : this._statusClass(t.Status__c),
            listingCommissionStatusClass : 'commission-status commission-status--pending',
            buyingCommissionStatusClass  : 'commission-status commission-status--pending',
            contractMilestoneClass       : `milestone-dot ${t.Contract_Date__c       ? 'milestone-dot--done' : 'milestone-dot--pending'}`,
            inspectionMilestoneClass     : `milestone-dot ${t.Inspection_Date__c     ? 'milestone-dot--done' : 'milestone-dot--pending'}`,
            appraisalMilestoneClass      : `milestone-dot ${t.Appraisal_Date__c      ? 'milestone-dot--done' : 'milestone-dot--pending'}`,
            closingMilestoneClass        : `milestone-dot ${t.Actual_Closing_Date__c ? 'milestone-dot--done' : 'milestone-dot--pending'}`,
            mortgageBadgeClass           : 'status-badge'
        };
    }

    // ── Agent options ─────────────────────────────
    _buildAgentOptions(txns) {
        const seen = new Map();
        txns.forEach(t => {
            if (t.Listing_Agent__c && t.Listing_Agent__r?.Name) seen.set(t.Listing_Agent__c, t.Listing_Agent__r.Name);
            if (t.Buying_Agent__c  && t.Buying_Agent__r?.Name)  seen.set(t.Buying_Agent__c,  t.Buying_Agent__r.Name);
        });

        if (seen.size === 0) {
            // No agents in data → hide the filter entirely (showAgentFilter = false)
            this.agentOptions = [];
            return;
        }

        this.agentOptions = [
            { label: 'Bütün agentlər', value: '' },
            ...Array.from(seen.entries()).map(([v, l]) => ({ label: l, value: v }))
        ];
    }

    // ── Filters ──────────────────────────────────
    handleSearch(e)       { this.searchKey     = e.target.value?.toLowerCase() || ''; this.prepareData(); }
    handleAgentFilter(e)  { this.selectedAgent = e.detail.value;  this.prepareData(); }

    /**
     * Date inputs: capture the string value without re-rendering immediately
     * so the native date picker does not scroll/jump while open.
     * We use a short debounce so the picker can close first.
     */
    handleCloseDateFrom(e) {
        const val = e.detail.value;
        clearTimeout(this._dateDebounce);
        this._dateDebounce = setTimeout(() => { this.closeDateFrom = val; this.prepareData(); }, 200);
    }

    handleCloseDateTo(e) {
        const val = e.detail.value;
        clearTimeout(this._dateDebounce);
        this._dateDebounce = setTimeout(() => { this.closeDateTo = val; this.prepareData(); }, 200);
    }

    handleMinPrice(e)     { this.minPrice = parseFloat(e.detail.value) || null; this.prepareData(); }
    handleMaxPrice(e)     { this.maxPrice = parseFloat(e.detail.value) || null; this.prepareData(); }

    resetFilters() {
        this.searchKey = ''; this.selectedAgent = '';
        this.closeDateFrom = ''; this.closeDateTo = '';
        this.minPrice = null; this.maxPrice = null;
        this.prepareData();
    }

    _applyFilters(txns) {
        return txns.filter(t => {
        if (this.searchKey) {
            const address = (t.Property__r?.Address__c || '').toLowerCase();
            const buyer   = (t.Buyer__r?.Name          || '').toLowerCase();
            // ✅ Hem adres hem buyer adında arar
            if (!address.includes(this.searchKey) && !buyer.includes(this.searchKey)) return false;
        }            // if (this.selectedAgent) {
            //     if (t.Listing_Agent__c !== this.selectedAgent && t.Buying_Agent__c !== this.selectedAgent) return false;
            // }
            if (this.closeDateFrom && t.Est_Closing_Date__c && new Date(t.Est_Closing_Date__c) < new Date(this.closeDateFrom)) return false;
            if (this.closeDateTo   && t.Est_Closing_Date__c && new Date(t.Est_Closing_Date__c) > new Date(this.closeDateTo))   return false;
            const p = t.Sale_Price__c || 0;
            if (this.minPrice !== null && p < this.minPrice) return false;
            if (this.maxPrice !== null && p > this.maxPrice) return false;
            return true;
        });
    }

    // ── Side Panel ───────────────────────────────
    openDetails(event) {
        event.stopPropagation();
        const id  = event.currentTarget.dataset.id;
        const raw = this.transactions.find(t => t.Id === id);
        if (!raw) return;
        this.selectedTransaction = this._decorate(raw);
        this.stageSteps = this._buildSteps(raw.Status__c);
    }

    closePanel() {
        this.selectedTransaction = null;
        this.stageSteps = [];
    }

    _buildSteps(current) {
        const ci = STAGES.indexOf(current);
        return STAGES.map((stage, i) => ({
            stage,
            stepClass: i < ci ? 'step done' : i === ci ? 'step active' : 'step'
        }));
    }

    // ── Advance Stage ────────────────────────────
advanceFromPanel(event) {
    const id  = event.currentTarget.dataset.id;
    const txn = this.transactions.find(t => t.Id === id);
    if (!txn) return;

    const ci = STAGES.indexOf(txn.Status__c);
    if (ci < 0 || ci >= STAGES.length - 1) return;

    const newStatus = STAGES[ci + 1];

    this._doAdvance(id, newStatus).then(() => {
        // ✅ Panel-i yenilə
        const updated = this.transactions.find(t => t.Id === id);
        if (updated) {
            this.selectedTransaction = this._decorate(updated);
            this.stageSteps = this._buildSteps(updated.Status__c);
        }
    });
}

    dragStart(event) {
        event.stopPropagation();
        event.dataTransfer.setData('tid', event.currentTarget.dataset.id);
    }

    allowDrop(event) {
        event.preventDefault();
        event.currentTarget.classList.add('drag-over');
    }

    drop(event) {
        event.preventDefault();
        event.currentTarget.classList.remove('drag-over');
        const tid       = event.dataTransfer.getData('tid');
        const newStatus = event.currentTarget.dataset.stage;
        if (!tid || !newStatus) return;
        const txn = this.transactions.find(t => t.Id === tid);
        if (!txn || txn.Status__c === newStatus) return;
        const ci = STAGES.indexOf(txn.Status__c);
        const ni = STAGES.indexOf(newStatus);
        if (ni !== ci + 1) {
            this._toast('Xəta', `"${txn.Status__c}" → "${newStatus}" keçidi etibarsızdır.`, 'error');
            return;
        }
        this._doAdvance(tid, newStatus);
    }

    _doAdvance(transactionId, newStatus) {
    this.isLoading = true;

    // ✅ Salesforce cavab gözləmədən lokal statusu dərhal yenilə
    this.transactions = this.transactions.map(t =>
        t.Id === transactionId ? { ...t, Status__c: newStatus } : t
    );
    this.prepareData();

    return advanceStage({ transactionId, newStatus })
        .then(() => {
            this._toast('Uğurlu', `"${newStatus}" mərhələsinə köçürüldü`, 'success');
            return refreshApex(this._wiredResult);
        })
        .catch(err => {
            // ✅ Xəta olarsa köhnə datanı geri yüklə
            return refreshApex(this._wiredResult).then(() => {
                this._toast('Xəta', err.body?.message || 'Yeniləmə uğursuz oldu', 'error');
            });
        })
        .finally(() => { this.isLoading = false; });
}
    // ── Helpers ──────────────────────────────────
    _urgency(t) {
        const d = this._daysLeft(t);
        if (d === null) return 'ok';
        if (d <= 7)  return 'urgent';
        if (d <= 14) return 'warn';
        return 'ok';
    }

    _daysLeft(t) {
        if (!t.Est_Closing_Date__c) return null;
        return Math.ceil((new Date(t.Est_Closing_Date__c) - new Date()) / 86400000);
    }

    _daysInStage(t) {
        if (!t.CreatedDate) return 0;
        return Math.floor((new Date() - new Date(t.CreatedDate)) / 86400000);
    }

    _nextLabel(t) {
        const i = STAGES.indexOf(t.Status__c);
        return i < 0 || i >= STAGES.length - 1 ? 'Tamamlandı' : `${STAGES[i + 1]} Mərhələsinə Köçür`;
    }

    _initials(name) {
        if (!name) return '?';
        const p = name.trim().split(/\s+/);
        return p.length >= 2 ? (p[0][0] + p[p.length - 1][0]).toUpperCase() : p[0].slice(0, 2).toUpperCase();
    }

    _fmtDate(d) {
        if (!d) return '—';
        return new Date(d).toLocaleDateString('az-AZ', { day: 'numeric', month: 'short', year: 'numeric' });
    }

    _statusClass(s) {
        const m = {
            'Pipeline'      : 'status-badge status-badge--pipeline',
            'Under Contract': 'status-badge status-badge--contract',
            'Inspection'    : 'status-badge status-badge--inspection',
            'Appraisal'     : 'status-badge status-badge--appraisal',
            'Closing'       : 'status-badge status-badge--closing',
            'Closed'        : 'status-badge status-badge--closed'
        };
        return m[s] || 'status-badge';
    }

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}