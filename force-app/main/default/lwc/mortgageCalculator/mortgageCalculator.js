import { LightningElement, api, track } from 'lwc';
import calculate from '@salesforce/apex/MortgageCalculatorService.calculateMonthlyPayment';
import createApp from '@salesforce/apex/MortgageCalculatorService.createMortgageApplication';

export default class MortgageCalculator extends LightningElement {

    @api recordId;
    @api buyerId;

    // INPUTS
    @track homePrice = 0;
    @track downPaymentPercent = 20;
    @track interestRate = 5;
    @track loanTerm = 30;

    // OUTPUTS
    @track monthlyPayment = 0;
    @track principal = 0;
    @track interest = 0;
    @track ltv = 0;

    // EXTRA
    @track amortization = [];
    @track income = 0;
    @track debts = 0;
    @track affordable = 0;

    debounceTimer;

    // ======================
    // SAFE NUMBER PARSE
    // ======================
    parseNumber(value) {
        const n = parseFloat(value);
        return isNaN(n) ? 0 : n;
    }

    // ======================
    // INPUT CHANGE
    // ======================
    handleChange(event) {
        const field = event.target.name;
        this[field] = this.parseNumber(event.target.value);
        this.debounceCalc();
    }

    // ======================
    // SAFE DEBOUNCE (NO setTimeout BUG)
    // ======================
debounceCalc() {
    if (this.debounceTimer) {
        clearTimeout(this.debounceTimer);
    }

    Promise.resolve().then(() => {
        this.calculate();
    });
}
    // ======================
    // MAIN CALCULATION
    // ======================
    calculate() {
        calculate({
            homePrice: this.homePrice,
            downPaymentPercent: this.downPaymentPercent,
            interestRate: this.interestRate,
            loanTerm: this.loanTerm
        })
        .then(res => {

            this.monthlyPayment = res.monthlyPayment || 0;
            this.principal = res.principal || 0;
            this.interest = res.interest || 0;
            this.ltv = res.ltv || 0;

            this.buildAmortization();
        })
        .catch(err => {
            console.error('Calculation error:', err);
        });
    }

    // ======================
    // AMORTIZATION + BAR STYLES
    // ======================
    buildAmortization() {

        let balance = this.principal;
        const r = this.interestRate / 100 / 12;
        const months = this.loanTerm * 12;

        const schedule = [];

        for (let i = 1; i <= months; i++) {

            const interestPart = balance * r;
            const principalPart = this.monthlyPayment - interestPart;

            balance -= principalPart;

            schedule.push({
                month: i,
                payment: this.monthlyPayment,
                interest: interestPart,
                principal: principalPart,
                balance: Math.max(balance, 0)
            });
        }

        // 🔥 FIX: STYLE CALC SAFE (NO DIV BY ZERO)
        this.amortization = schedule.map(a => {

            const total = a.principal + a.interest;

            return {
                ...a,
                principalStyle: total
                    ? `width:${(a.principal / total) * 100}%`
                    : 'width:0%',
                interestStyle: total
                    ? `width:${(a.interest / total) * 100}%`
                    : 'width:0%'
            };
        });
    }

    // ======================
    // AFFORDABILITY
    // ======================
    calculateAffordability() {

        const income = this.parseNumber(this.income);
        const debts = this.parseNumber(this.debts);

        const monthlyIncome = income / 12;
        const maxPayment = (monthlyIncome * 0.43) - debts;

        this.affordable = maxPayment > 0 ? maxPayment * 12 : 0;
    }

    // ======================
    // APPLY MORTGAGE
    // ======================
    applyMortgage() {

        if (!this.recordId || !this.buyerId) {
            console.error('Missing recordId or buyerId');
            return;
        }

        createApp({
            propertyId: this.recordId,
            buyerId: this.buyerId,
            homePrice: this.homePrice,
            downPaymentPercent: this.downPaymentPercent,
            interestRate: this.interestRate,
            loanTerm: this.loanTerm
        })
        .then(() => {
            console.log('Mortgage Application Created');
        })
        .catch(err => {
            console.error('Mortgage creation error:', err);
        });
    }
}