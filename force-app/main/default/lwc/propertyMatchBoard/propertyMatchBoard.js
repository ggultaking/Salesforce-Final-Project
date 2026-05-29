import { LightningElement, wire, api, track } from 'lwc';

import getTopMatches
from '@salesforce/apex/PropertyMatchController.getTopMatches';

import markNotInterested
from '@salesforce/apex/PropertyMatchController.markNotInterested';

import restoreHiddenMatches
from '@salesforce/apex/PropertyMatchController.restoreHiddenMatches';

import scheduleShowing
from '@salesforce/apex/PropertyMatchController.scheduleShowing';

import getOfferSummaries
from '@salesforce/apex/PropertyMatchController.getOfferSummaries';

import getPropertyOffersWithNegotiations
from '@salesforce/apex/PropertyMatchController.getPropertyOffersWithNegotiations';

import getPropertyPhotos
from '@salesforce/apex/PropertyMatchController.getPropertyPhotos';

import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPropertyCounts
from '@salesforce/apex/PropertyMatchController.getPropertyCounts';

export default class PropertyMatchBoard extends LightningElement {

    @api recordId;

    @track matches    = [];
    allMatches        = [];
    wiredResult;
    offerSummaryMap   = {};

    minPrice  = 0;
    maxPrice  = 1000000;
    minScore  = 0;
    hotOnly   = false;
    countMap  = {};

    _activeMinPrice  = 0;
    _activeMaxPrice  = 1000000;
    _activeMinScore  = 0;
    _activeHotOnly   = false;
    _filtersApplied  = false;

    isLoading = false;

    totalMatches = 0;
    hotCount     = 0;
    avgScore     = 0;
    totalViewed  = 0;

    showMortgageModal    = false;
    showScheduleModal    = false;
    showOfferFlow        = false;
    showCounterOfferFlow = false;

    selectedDuration = 30;
    get durationPills() {
        return [
            { label: '15 min', value: 15,  pillClass: this._pillClass(15)  },
            { label: '30 min', value: 30,  pillClass: this._pillClass(30)  },
            { label: '45 min', value: 45,  pillClass: this._pillClass(45)  },
            { label: '1 hour', value: 60,  pillClass: this._pillClass(60)  },
            { label: '90 min', value: 90,  pillClass: this._pillClass(90)  },
        ];
    }

    _pillClass(val) {
        return val === this.selectedDuration
            ? 'schedule-duration-pill active'
            : 'schedule-duration-pill';
    }

    showPhotoSlider      = false;
    sliderPhotos         = [];
    sliderCurrentIndex   = 0;
    sliderPropertyName   = '';

    showOfferKanban      = false;
    kanbanOffers         = [];
    kanbanPropertyName   = '';

    selectedPropertyId;
    selectedPropertyMatchId;
    selectedPrice;
    selectedDate;

    offerFlowMatchId             = null;
    offerFlowPropertyId          = null;
    offerFlowInputVariables      = [];
    counterOfferFlowInputVariables = [];

    // =====================================================
    // WIRED APEX
    // =====================================================
    @wire(getTopMatches, { buyerId: '$recordId' })
    wiredMatches(result) {
        this.wiredResult = result;

        if (result.data) {
            const safeData = Array.isArray(result.data) ? result.data : [];

            this.allMatches = safeData.map(x => {
                const rawStatus  = x?.status || x?.Status__c || x?.Status || '';
                const statusNorm = String(rawStatus).toLowerCase().trim();
                const status     = rawStatus || 'Matched';

                return {
                    ...x,
                    propertyMatchId : x?.propertyMatchId ?? x?.Id ?? null,
                    propertyId      : x?.propertyId ?? x?.Property__c,
                    interestLevel   : x?.interestLevel,
                    interestClass   : this.getInterestClass(x?.interestLevel),
                    imageUrl        : x?.photoUrl || '/img/sample-property.jpg',
                    viewedCount     : x?.viewedCount  || 0,
                    showingCount    : x?.showingCount || 0,
                    matchScore      : Number(x?.matchScore) || 0,
                    price           : Number(x?.price) || 0,
                    address         : x?.address,
                    city            : x?.city,
                    status,
                    statusNorm,
                    budgetStyle     : this.barStyle(x?.breakdown?.budgetScore),
                    locationStyle   : this.barStyle(x?.breakdown?.locationScore),
                    typeStyle       : this.barStyle(x?.breakdown?.typeScore),
                    roomsStyle      : this.barStyle(x?.breakdown?.roomsScore),
                    areaStyle       : this.barStyle(x?.breakdown?.areaScore),
                    featuresStyle   : this.barStyle(x?.breakdown?.featuresScore),
                    breakdown       : {
                        budgetScore   : this.fmtScore(x?.breakdown?.budgetScore),
                        locationScore : this.fmtScore(x?.breakdown?.locationScore),
                        typeScore     : this.fmtScore(x?.breakdown?.typeScore),
                        roomsScore    : this.fmtScore(x?.breakdown?.roomsScore),
                        areaScore     : this.fmtScore(x?.breakdown?.areaScore),
                        featuresScore : this.fmtScore(x?.breakdown?.featuresScore),
                    },
                    offerCount             : 0,
                    hasOffer               : false,
                    canOffer               : false,
                    showOfferButton        : false,
                    showCounterOfferButton : false
                };
            });

            this.allMatches = [...this.allMatches];
            this._loadOfferSummaries();
        }

        if (result.error) {
            console.error('getTopMatches error:', result.error);
        }
    }

    // =====================================================
    // OFFER SUMMARY
    // =====================================================
    _loadOfferSummaries() {
        const matchIds = this.allMatches
            .map(m => m.propertyMatchId)
            .filter(Boolean);

        if (!matchIds.length) {
            this.applyView();
            this.calculateStats();
            return;
        }

        Promise.all([
            getOfferSummaries({ propertyMatchIds: matchIds }),
            getPropertyCounts({ propertyMatchIds: matchIds, buyerId: this.recordId })
        ])
        .then(([summaries, counts]) => {
            const offerMap = {};
            if (Array.isArray(summaries)) {
                summaries.forEach(s => {
                    offerMap[s.propertyMatchId] = {
                        offerCount : s.offerCount || 0,
                        hasOffer   : (s.offerCount || 0) > 0
                    };
                });
            }
            this.offerSummaryMap = offerMap;
            this.countMap = counts || {};

            this._enrichMatchesWithOffers();
            this.applyView();
            this.calculateStats();
        })
        .catch(err => {
            console.error('load summaries/counts error:', err);
            this.applyView();
            this.calculateStats();
        });
    }

    _enrichMatchesWithOffers() {
        this.allMatches = this.allMatches.map(m => {
            const summary    = this.offerSummaryMap[m.propertyMatchId] || {};
            const offerCount = summary.offerCount || 0;
            const hasOffer   = offerCount > 0;

            const counts       = this.countMap || {};
            const viewedCount  = counts['viewed_'    + m.propertyMatchId] ?? m.viewedCount  ?? 0;
            const showingCount = counts['showing_'   + m.propertyMatchId] ?? m.showingCount ?? 0;
            const buyerOffer   = counts['buyerOffer_' + m.propertyMatchId] ?? 0;
            const buyerNeg     = counts['buyerNeg_'   + m.propertyMatchId] ?? 0;

            const buyerHasSeen  = showingCount > 0;
            const buyerHasOffer = buyerOffer > 0;
            const buyerHasNeg   = buyerNeg > 0;

            const showOfferButton        = buyerHasSeen && !buyerHasOffer;
            const showCounterOfferButton = buyerHasSeen && buyerHasOffer && buyerHasNeg;

            return {
                ...m,
                viewedCount,
                showingCount,
                offerCount,
                hasOffer,
                showOfferButton,
                showCounterOfferButton
            };
        });
    }

    // =====================================================
    // HELPERS
    // =====================================================
    fmtScore(score) {
        if (score == null) return 0;
        return parseFloat(Number(score).toFixed(2));
    }

    barStyle(score) {
        const pct = score != null ? Math.min(Number(score), 100) : 0;
        return `width: ${parseFloat(pct.toFixed(2))}%`;
    }

    isNotInterested(m) {
        const fields = [
            m?.statusNorm,
            String(m?.status    || '').toLowerCase().trim(),
            String(m?.Status__c || '').toLowerCase().trim(),
            String(m?.Status    || '').toLowerCase().trim()
        ];
        return fields.some( f =>f === 'not interested' || f === 'sold' || f === 'closed');
    }

    // =====================================================
    // VIEW ENGINE
    // =====================================================
    applyView() {
        const base = [...this.allMatches].filter(m => !this.isNotInterested(m));

        if (!this._filtersApplied) {
            this.matches = base;
        } else {
            this.matches = base.filter(m => {
                const priceOk = m.price >= this._activeMinPrice && m.price <= this._activeMaxPrice;
                const scoreOk = this._activeMinScore === 0 || m.matchScore >= this._activeMinScore;
                const hotOk   = !this._activeHotOnly || m.interestLevel === 'Hot';
                return priceOk && scoreOk && hotOk;
            });
        }
    }

    // =====================================================
    // STATS
    // =====================================================
    calculateStats() { this.calculateStatsFromFiltered(this.matches); }

    calculateStatsFromFiltered(list) {
        this.totalMatches = list.length;
        this.hotCount     = list.filter(m => m.interestLevel === 'Hot').length;
        this.totalViewed  = list.reduce((s, m) => s + (m.viewedCount || 0), 0);
        const avg         = list.length
            ? list.reduce((s, m) => s + (m.matchScore || 0), 0) / list.length
            : 0;
        this.avgScore = avg.toFixed(1);
    }

    // =====================================================
    // FILTERS
    // =====================================================
    handleMinPrice(e) { this.minPrice = Number(e.target.value || 0); }
    handleMaxPrice(e) { this.maxPrice = Number(e.target.value || 1000000); }
    handleMinScore(e) { this.minScore = Number(e.target.value || 0); }
    handleHotOnly(e)  { this.hotOnly  = e.target.checked; }

    applyFilters() {
        this.isLoading       = true;
        this._activeMinPrice = this.minPrice;
        this._activeMaxPrice = this.maxPrice;
        this._activeMinScore = this.minScore;
        this._activeHotOnly  = this.hotOnly;
        this._filtersApplied = true;

        setTimeout(() => {
            const base     = this.allMatches.filter(m => !this.isNotInterested(m));
            const filtered = base.filter(m => {
                const priceOk = m.price >= this.minPrice && m.price <= this.maxPrice;
                const scoreOk = this.minScore === 0 || m.matchScore >= this.minScore;
                const hotOk   = !this.hotOnly || m.interestLevel === 'Hot';
                return priceOk && scoreOk && hotOk;
            });
            this.matches = [...filtered];
            this.calculateStatsFromFiltered(filtered);
            this.isLoading = false;
        }, 120);
    }

    resetFilters() {
        this.minPrice = 0; this.maxPrice = 1000000;
        this.minScore = 0; this.hotOnly  = false;
        this._activeMinPrice = 0; this._activeMaxPrice = 1000000;
        this._activeMinScore = 0; this._activeHotOnly  = false;
        this._filtersApplied = false;
        this.applyView();
        this.calculateStats();
    }

    // =====================================================
    // SHOW HIDDEN
    // =====================================================
    showHidden() {
        restoreHiddenMatches({ buyerId: this.recordId })
            .then(async () => {
                this.toast('Success', 'Hidden matches restored', 'success');
                this.allMatches = this.allMatches.map(m => {
                    if (this.isNotInterested(m)) {
                        return { ...m, status: 'Matched', statusNorm: 'matched' };
                    }
                    return m;
                });
                this.applyView();
                this.calculateStats();
                await refreshApex(this.wiredResult);
            })
            .catch(err => {
                console.error(err);
                this.toast('Error', 'Restore failed', 'error');
            });
    }

    // =====================================================
    // NOT INTERESTED
    // =====================================================
    markNotInterested(event) {
        event.stopPropagation();
        const id = event.currentTarget.dataset.id;
        if (!id) return;

        markNotInterested({ propertyMatchId: id })
            .then(() => {
                this.toast('Success', 'Marked Not Interested', 'success');
                this.allMatches = this.allMatches.map(m => {
                    if (m.propertyMatchId === id) {
                        return { ...m, status: 'Not Interested', statusNorm: 'not interested' };
                    }
                    return m;
                });
                this.applyView();
                this.calculateStats();
            })
            .catch(err => {
                console.error(err);
                this.toast('Error', 'Action failed', 'error');
            });
    }

    // =====================================================
    // SCHEDULE
    // =====================================================
    openSchedule(event) {
        event.stopPropagation();
        this.selectedPropertyMatchId = event.currentTarget.dataset.matchid;
        this.selectedDuration        = 30;
        this.selectedDate            = null;
        this.showScheduleModal       = true;
    }

    handleDateChange(e) { this.selectedDate = e.target.value; }

    handleDurationPill(event) {
        event.stopPropagation();
        const val = parseInt(event.currentTarget.dataset.value, 10);
        if (!isNaN(val)) this.selectedDuration = val;
    }

    closeModal() {
        this.showScheduleModal       = false;
        this.selectedPropertyMatchId = null;
        this.selectedDate            = null;
    }

    saveSchedule() {
        if (!this.selectedPropertyMatchId || !this.selectedDate) {
            this.toast('Error', 'Please select a date and time', 'error');
            return;
        }

        const dt = new Date(this.selectedDate);
        const isoString = dt.toISOString();

        scheduleShowing({
            propertyMatchId : this.selectedPropertyMatchId,
            buyerId         : this.recordId,
            showingDateTime : isoString,
            durationMinutes : this.selectedDuration
        })
            .then(async () => {
                this.toast('Success', 'Showing scheduled successfully', 'success');
                this.closeModal();
                await refreshApex(this.wiredResult);
            })
            .catch(err => {
                console.error(err);
                this.toast('Error', err?.body?.message || 'Schedule failed', 'error');
            });
    }

    // =====================================================
    // MAP
    // =====================================================
    openMap(event) {
        event.stopPropagation();
        const propertyId = event.currentTarget.dataset.propertyid;
        if (!propertyId) return;
        const item = this.allMatches.find(x => x.propertyId === propertyId);
        if (!item || !item.address) return;
        const query = encodeURIComponent(
            [item.address, item.city].filter(Boolean).join(', ')
        );
        window.open(`https://www.google.com/maps/search/?api=1&query=${query}`, '_blank');
    }

    // =====================================================
    // MORTGAGE
    // =====================================================
    openMortgage(event) {
        event.stopPropagation();
        const matchId = event.currentTarget.dataset.matchid;
        if (!matchId) return;
        const item = this.allMatches.find(x => x.propertyMatchId === matchId);
        if (!item) return;
        this.selectedPropertyId = item.propertyId;
        this.selectedPrice      = item.price;
        this.showMortgageModal  = true;
    }

    closeMortgage() {
        this.showMortgageModal  = false;
        this.selectedPropertyId = null;
        this.selectedPrice      = null;
    }

    handleMortgageApplied(event) {
        const appId = event.detail?.mortgageApplicationId;
        console.log('[Board] Mortgage Application:', appId);
        this.closeMortgage();
        this.toast('Success', 'Mortgage application created!', 'success');
    }

    // =====================================================
    // PHOTO SLIDER
    // =====================================================
    openPhotoSlider(event) {
        event.stopPropagation();
        const propertyId   = event.currentTarget.dataset.propertyid;
        const propertyName = event.currentTarget.dataset.address || '';
        if (!propertyId) return;

        this.sliderPropertyName = propertyName;
        this.sliderCurrentIndex = 0;

        getPropertyPhotos({ propertyId })
            .then(photos => {
                if (photos && photos.length > 0) {
                    this.sliderPhotos = photos.map((url, i) => ({
                        url,
                        index     : i,
                        isActive  : i === 0,
                        dotClass  : i === 0 ? 'slider-dot active' : 'slider-dot'
                    }));
                } else {
                    this.sliderPhotos = [{
                        url      : '/img/sample-property.jpg',
                        index    : 0,
                        isActive : true,
                        dotClass : 'slider-dot active'
                    }];
                }
                this.showPhotoSlider = true;
            })
            .catch(() => {
                this.sliderPhotos = [{
                    url      : '/img/sample-property.jpg',
                    index    : 0,
                    isActive : true,
                    dotClass : 'slider-dot active'
                }];
                this.showPhotoSlider = true;
            });
    }

    closePhotoSlider() {
        this.showPhotoSlider = false;
        this.sliderPhotos    = [];
    }

    sliderPrev(event) {
        event.stopPropagation();
        const newIndex = (this.sliderCurrentIndex - 1 + this.sliderPhotos.length) % this.sliderPhotos.length;
        this._setSliderIndex(newIndex);
    }

    sliderNext(event) {
        event.stopPropagation();
        const newIndex = (this.sliderCurrentIndex + 1) % this.sliderPhotos.length;
        this._setSliderIndex(newIndex);
    }

    sliderDotClick(event) {
        event.stopPropagation();
        const idx = parseInt(event.currentTarget.dataset.index, 10);
        this._setSliderIndex(idx);
    }

    _setSliderIndex(index) {
        this.sliderCurrentIndex = index;
        this.sliderPhotos = this.sliderPhotos.map((p, i) => ({
            ...p,
            isActive : i === index,
            dotClass : i === index ? 'slider-dot active' : 'slider-dot'
        }));
    }

    get sliderCurrentPhoto() {
        return this.sliderPhotos[this.sliderCurrentIndex]?.url || '/img/sample-property.jpg';
    }

    get sliderHasMultiple() {
        return this.sliderPhotos.length > 1;
    }

    get sliderCounter() {
        return `${this.sliderCurrentIndex + 1} / ${this.sliderPhotos.length}`;
    }

    // =====================================================
    // OFFER KANBAN — buyerId ilə həm Offer həm CounterOffer
    // =====================================================
    openOfferKanban(event) {
        event.stopPropagation();
        const propertyId   = event.currentTarget.dataset.propertyid;
        const propertyName = event.currentTarget.dataset.address || '';
        if (!propertyId) return;

        this.kanbanPropertyName = propertyName;

        // ← getPropertyOffersWithNegotiations istifadə edirik, buyerId ötürürük
        getPropertyOffersWithNegotiations({
            propertyId : propertyId,
            buyerId    : this.recordId
        })
            .then(items => {
                this.kanbanOffers = (items || []).map(item => {
                    const isCounterOffer = item.type === 'CounterOffer';
                    const amount = isCounterOffer
                        ? item.amount          // Counter_Offer_Amount__c
                        : item.amount;         // Offer_Amount__c

                    const amountFormatted = amount
                        ? new Intl.NumberFormat('az-AZ', {
                            style                : 'currency',
                            currency             : 'AZN',
                            maximumFractionDigits: 0
                          }).format(amount)
                        : '—';

                    const submittedDate = item.createdDate
                        ? new Date(item.createdDate).toLocaleDateString('az-AZ', {
                            day: 'numeric', month: 'short', year: 'numeric'
                          })
                        : '—';

                    const status   = item.status || '';
                    const buyerName = item.buyerName || '—';

                    // Kanban sütun məntiqi:
                    // CounterOffer-lər həmişə "Active / Countered" sütununa düşür
                    const isSubmitted        = !isCounterOffer && status === 'Submitted';
                    const isActiveOrCountered = isCounterOffer
                        || status === 'Active'
                        || status === 'Countered';
                    const isAccepted         = !isCounterOffer && status === 'Accepted';
                    const isClosed           = !isCounterOffer &&
                        ['Rejected', 'Expired', 'Withdrawn'].includes(status);

                    // Kart üzərindəki etiket
                    const typeLabel = isCounterOffer ? 'Counter Offer' : 'Offer';

                    return {
                        ...item,
                        Id                   : item.id,
                        Status__c            : status,
                        amountFormatted,
                        buyerName,
                        submittedDate,
                        statusClass          : this._offerStatusClass(status, isCounterOffer),
                        typeLabel,
                        isCounterOffer,
                        isSubmitted,
                        isActiveOrCountered,
                        isAccepted,
                        isClosed,
                        cardClass            : isCounterOffer
                            ? 'kanban-offer-card counter-offer-card'
                            : 'kanban-offer-card'
                    };
                });
                this.showOfferKanban = true;
            })
            .catch(err => {
                console.error('getPropertyOffersWithNegotiations error:', err);
                this.toast('Error', 'Could not load offers', 'error');
            });
    }

    closeOfferKanban() {
        this.showOfferKanban = false;
        this.kanbanOffers    = [];
    }

    // isCounterOffer === true olduqda status "Countered" kimi rənglənir
    _offerStatusClass(status, isCounterOffer) {
        if (isCounterOffer) return 'offer-status offer-status--countered';
        const map = {
            'Submitted' : 'offer-status offer-status--submitted',
            'Active'    : 'offer-status offer-status--active',
            'Accepted'  : 'offer-status offer-status--accepted',
            'Rejected'  : 'offer-status offer-status--rejected',
            'Countered' : 'offer-status offer-status--countered',
            'Expired'   : 'offer-status offer-status--expired',
            'Withdrawn' : 'offer-status offer-status--withdrawn'
        };
        return map[status] || 'offer-status';
    }

    // =====================================================
    // OFFER FLOW
    // =====================================================
    openOfferFlow(event) {
        event.stopPropagation();
        const matchId    = event.currentTarget.dataset.matchid;
        const propertyId = event.currentTarget.dataset.propertyid;
        if (!matchId) return;

        this.offerFlowMatchId    = matchId;
        this.offerFlowPropertyId = propertyId;

        this.offerFlowInputVariables = [
            { name: 'recordId', type: 'String', value: matchId }
        ];

        this.showOfferFlow = true;
    }

    handleOfferFlowFinish(event) {
        const status = event.detail?.status;
        if (status !== 'FINISHED' && status !== 'FINISHED_SCREEN') return;

        this.showOfferFlow       = false;
        this.offerFlowMatchId    = null;
        this.offerFlowPropertyId = null;

        this.toast('Success', 'Offer submitted!', 'success');
        this._loadOfferSummaries();
    }

    closeOfferFlow() {
        this.showOfferFlow       = false;
        this.offerFlowMatchId    = null;
        this.offerFlowPropertyId = null;
    }

    // =====================================================
    // COUNTER OFFER FLOW
    // =====================================================
    openCounterOfferFlow(event) {
        event.stopPropagation();
        const matchId    = event.currentTarget.dataset.matchid;
        const propertyId = event.currentTarget.dataset.propertyid;
        if (!matchId) return;

        this.offerFlowMatchId    = matchId;
        this.offerFlowPropertyId = propertyId;

        this.counterOfferFlowInputVariables = [
            { name: 'recordId',   type: 'String', value: matchId      },
            { name: 'varBuyerId', type: 'String', value: this.recordId }
        ];

        this.showCounterOfferFlow = true;
    }

    handleCounterOfferFlowFinish(event) {
        const status = event.detail?.status;
        if (status !== 'FINISHED' && status !== 'FINISHED_SCREEN') return;

        this.showCounterOfferFlow = false;
        this.offerFlowMatchId     = null;
        this.offerFlowPropertyId  = null;

        this.toast('Success', 'Counter offer submitted!', 'success');
        this._loadOfferSummaries();
    }

    closeCounterOfferFlow() {
        this.showCounterOfferFlow = false;
        this.offerFlowMatchId     = null;
        this.offerFlowPropertyId  = null;
    }

    // =====================================================
    // HELPERS
    // =====================================================
    getInterestClass(level) {
        if (level === 'Hot')  return 'hot';
        if (level === 'Warm') return 'warm';
        return 'cold';
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}