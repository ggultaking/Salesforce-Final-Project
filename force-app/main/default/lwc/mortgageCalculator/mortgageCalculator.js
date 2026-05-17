import { LightningElement, api, track } from 'lwc';
import calculateMonthlyPayment from '@salesforce/apex/MortgageCalculatorService.calculateMonthlyPayment';
import createMortgageApplication from '@salesforce/apex/MortgageCalculatorService.createMortgageApplication';

export default class MortgageCalculator extends LightningElement {

    @api recordId; // Property Id

    @track homePrice = 0;
    @track downPaymentPercent = 20;
    @track interestRate = 5;
    @track loanTerm = 30;

    @track monthlyPayment = 0;
    @track principal = 0;
    @track interest = 0;
    @track ltv = 0;

    debounceTimer;

    connectedCallback() {
        // auto-fill from property (optional extension later)
    }

    // -----------------------
    // INPUT HANDLERS
    // -----------------------
    handleHomePrice(e) {
        this.homePrice = e.target.value;
        this.debounceCalc();
    }

    handleDownPaymentPercent(e) {
        this.downPaymentPercent = e.target.value;
        this.debounceCalc();
    }

    handleInterestRate(e) {
        this.interestRate = e.target.value;
        this.debounceCalc();
    }

    setTerm(e) {
        this.loanTerm = e.target.dataset.year;
        this.debounceCalc();
    }

    // -----------------------
    // DEBOUNCE CALCULATION
    // -----------------------
    debounceCalc() {
        clearTimeout(this.debounceTimer);

        this.debounceTimer = setTimeout(() => {
            this.calculate();
        }, 300);
    }

    calculate() {
        calculateMonthlyPayment({
            homePrice: this.homePrice,
            downPaymentPercent: this.downPaymentPercent,
            interestRate: this.interestRate,
            loanTerm: this.loanTerm
        })
        .then(res => {
            this.monthlyPayment = res.monthlyPayment;
            this.principal = res.principal;
            this.interest = res.interest;
            this.ltv = res.ltv;
        });
    }

    // -----------------------
    // APPLY MORTGAGE
    // -----------------------
    applyMortgage() {
        createMortgageApplication({
            propertyId: this.recordId,
            homePrice: this.homePrice,
            downPaymentPercent: this.downPaymentPercent,
            interestRate: this.interestRate,
            loanTerm: this.loanTerm
        }).then(() => {
            alert('Mortgage Application Created');
        });
    }

    get ltvClass() {
        if (this.ltv < 80) return 'green';
        if (this.ltv < 90) return 'yellow';
        return 'red';
    }
}