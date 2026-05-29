import { LightningElement, api, track, wire } from 'lwc';
import calculate from '@salesforce/apex/MortgageCalculatorService.calculateMonthlyPayment';
import createApp from '@salesforce/apex/MortgageCalculatorService.createMortgageApplication';
import { getRecord } from 'lightning/uiRecordApi';
import ASKING_PRICE from '@salesforce/schema/Property__c.Asking_Price__c';
import exportAmortization from '@salesforce/apex/MortgageCalculatorService.exportAmortization';
// FIX 3: getBuyerId import kaldırıldı — güvenilmez, buyerId artık parent'tan @api ile geliyor

export default class MortgageCalculator extends LightningElement {

    // =====================================================
    // API PROPS
    // =====================================================
    @api initialPrice;

    _propertyId;

    @api
    get propertyId() {
        return this._propertyId;
    }
    set propertyId(value) {
        this._propertyId = value;
    }

    // FIX 3: buyerId artık sadece parent'tan geliyor
    // Parent (PropertyMatchBoard) kendi recordId'sini geçirecek: buyer-id={recordId}
    // getBuyerId() Apex çağrısı kaldırıldı — o metod login kullanıcının agent olduğu
    // buyer'ı arıyor, büyük ihtimalle null dönüyor ve sessizce fail oluyor
    _buyerId;

    @api
    get buyerId() {
        return this._buyerId;
    }
    set buyerId(value) {
        this._buyerId = value;
    }

    // =====================================================
    // TRACKED STATE
    // =====================================================
    @track homePrice = 0;
    @track downPaymentPercent = 20;
    @track interestRate = 5;
    @track loanTerm = 30;

    @track monthlyPayment = 0;
    @track principal = 0;
    @track interest = 0;
    @track ltv = 0;

    @track amortization = [];
    @track income = 0;
    @track debts = 0;
    @track affordable = 0;

    showAffordability = false;
    isApplying = false;

    // =====================================================
    // WIRE — load asking price from Property record
    // =====================================================
    @wire(getRecord, { recordId: '$_propertyId', fields: [ASKING_PRICE] })
    wiredProperty({ data, error }) {
        if (data) {
            this.homePrice = data.fields.Asking_Price__c.value || 0;
        }
        if (error) {
            console.error('wiredProperty error:', error);
        }
    }

    // =====================================================
    // LIFECYCLE
    // =====================================================
    connectedCallback() {
        if (this.initialPrice) {
            this.homePrice = this.initialPrice;
        }
        // FIX 3: _ensureBuyerId() çağrısı kaldırıldı
        // buyerId artık parent'tan @api ile geliyor, burada çekmeye gerek yok
    }

    // =====================================================
    // INPUT HANDLERS
    // FIX 2: loanTerm her zaman parseInt ile integer'a çevriliyor
    // Apex Integer bekliyor — parseFloat("30") → 30.0 gelirse Apex null görür
    // =====================================================
    handleInput(event) {
        const val  = event.target.value;
        const name = event.target.name;
        if (name === 'loanTerm') {
            this[name] = val ? parseInt(val, 10) : 0;
        } else {
            this[name] = this.parseNumber(val);
        }
    }

    parseNumber(v) {
        const n = parseFloat(v);
        return isNaN(n) ? 0 : n;
    }

    // =====================================================
    // CALCULATE
    // =====================================================
    calculate() {

        if (!this.homePrice || this.homePrice <= 0) {
            console.error('Home Price missing or zero');
            return;
        }

        calculate({
            homePrice:          this.homePrice,
            downPaymentPercent: this.downPaymentPercent,
            interestRate:       this.interestRate,
            loanTerm:           parseInt(this.loanTerm, 10)  // FIX 2: integer garantisi
        })
            .then(res => {
                this.monthlyPayment = res.monthlyPayment || 0;
                this.principal      = res.principal      || 0;
                this.interest       = res.interest       || 0;
                this.ltv            = res.ltv            || 0;
                this.buildAmortization();
            })
            .catch(error => console.error('calculate error:', error));
    }

    buildAmortization() {

        let balance  = this.principal;
        const r      = this.interestRate / 100 / 12;
        const months = this.loanTerm * 12;
        const schedule = [];

        for (let i = 1; i <= months; i++) {

            let interestPart  = Number((balance * r).toFixed(2));
            let principalPart = Number((this.monthlyPayment - interestPart).toFixed(2));

            if (i === months) {
                principalPart = Number(balance.toFixed(2));
            }

            balance = Number((balance - principalPart).toFixed(2));

            schedule.push({
                month:     i,
                payment:   this.monthlyPayment.toFixed(2),
                interest:  interestPart.toFixed(2),
                principal: principalPart.toFixed(2),
                balance:   Math.max(balance, 0).toFixed(2)
            });
        }

        this.amortization = schedule;
    }

    // =====================================================
    // AFFORDABILITY — 2 decimal places on result
    // =====================================================
    calculateAffordability() {
        const monthlyIncome = this.income / 12;
        const maxPayment    = (monthlyIncome * 0.43) - this.debts;
        const raw           = maxPayment > 0 ? maxPayment * 12 : 0;
        this.affordable       = Number(raw.toFixed(2));
        this.showAffordability = true;
    }

    // =====================================================
    // EXPORT TO EXCEL (CSV via Apex base64)
    // =====================================================
    exportToExcel() {
        if (!this.homePrice || !this.interestRate || !this.loanTerm) return;

        exportAmortization({ schedule: this.amortization })
            .then(res => {
                const link    = document.createElement('a');
                link.href     = 'data:text/csv;base64,' + res;
                link.download = 'amortization.csv';
                link.click();
            })
            .catch(err => console.error('exportAmortization error:', err));
    }

    // =====================================================
    // APPLY MORTGAGE
    // FIX 1: _ensureBuyerId() kaldırıldı, this._buyerId doğrudan kullanılıyor
    // FIX 2: loanTerm parseInt ile integer'a çevriliyor
    // FIX 3: buyerId artık parent'tan @api ile geliyor (buyer-id={recordId})
    // =====================================================
    applyMortgage() {

        if (!this._propertyId) {
            console.error('applyMortgage: propertyId is missing');
            return;
        }

        if (!this._buyerId) {
            console.error('applyMortgage: buyerId is missing — parent buyer-id={recordId} geçiyor mu?');
            return;
        }

        if (this.isApplying) return;
        this.isApplying = true;

        createApp({
            propertyId:         this._propertyId,
            buyerId:            this._buyerId,
            homePrice:          this.homePrice,
            downPaymentPercent: this.downPaymentPercent,
            interestRate:       this.interestRate,
            loanTerm:           parseInt(this.loanTerm, 10)  // FIX 2: integer
        })
            .then(result => {
                if (result) {
                    console.log('Mortgage Application created. Id:', result);
                    this.dispatchEvent(
                        new CustomEvent('mortgageapplied', {
                            detail: { mortgageApplicationId: result }
                        })
                    );
                }
            })
            .catch(error => {
    console.error('body:', JSON.stringify(error?.body));
    console.error('message:', error?.body?.message);
    console.error('stackTrace:', error?.body?.stackTrace);
})
            .finally(() => {
                this.isApplying = false;
            });
    }

    // =====================================================
    // CLOSE — fires event so parent modal can close
    // =====================================================
    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    // =====================================================
    // CHART DATA GETTERS (kept for compatibility)
    // =====================================================
    get chartData() {
        const data = (this.amortization || []).map(x => ({
            month:     x.month,
            principal: Number(x.principal),
            interest:  Number(x.interest),
            balance:   Number(x.balance)
        }));
        return {
            chartType: 'line',
            meta:  { title: 'Mortgage Amortization', description: 'Principal vs Interest vs Remaining Balance' },
            xKey:  'month',
            series: [
                { dataKey: 'principal', label: 'Principal', valueFormat: 'raw' },
                { dataKey: 'interest',  label: 'Interest',  valueFormat: 'raw' },
                { dataKey: 'balance',   label: 'Balance',   valueFormat: 'raw' }
            ],
            data
        };
    }

    get chartWidget() {
        return {
            chartType: 'line',
            meta:  { title: 'Mortgage Trend' },
            xKey:  'month',
            series: [
                { dataKey: 'principal', label: 'Principal' },
                { dataKey: 'interest',  label: 'Interest'  },
                { dataKey: 'balance',   label: 'Balance'   }
            ],
            data: this.amortization || []
        };
    }
}