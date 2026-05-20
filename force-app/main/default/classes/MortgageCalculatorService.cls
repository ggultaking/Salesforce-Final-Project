public class MortgageCalculatorService {

    // ==============================
    // CORE MATH
    // ==============================
    public static Decimal calculateMonthlyPayment(
        Decimal loanAmount,
        Decimal annualRate,
        Integer termYears
    ) {
        if (loanAmount == null || annualRate == null || termYears == null) {
            return 0;
        }

        Double r = annualRate.doubleValue() / 100.0 / 12.0;
        Integer n = termYears * 12;

        if (r == 0 || n == 0) {
            return loanAmount / Math.max(n, 1);
        }

        Double pow = Math.pow(1 + r, n);

        Double payment =
            loanAmount.doubleValue() *
            (r * pow) /
            (pow - 1);

        return Decimal.valueOf(payment).setScale(2);
    }

    // ==============================
    // AFFORDABILITY (BASE)
    // ==============================
    public static Decimal calculateAffordability(
        Decimal income,
        Decimal debts
    ) {
        if (income == null) income = 0;
        if (debts == null) debts = 0;

        Decimal monthlyIncome = income / 12;
        Decimal maxPayment = (monthlyIncome * 0.43) - debts;

        return maxPayment > 0 ? maxPayment * 12 : 0;
    }

    // =====================================================
    // LWC WRAPPER - MONTHLY PAYMENT
    // =====================================================
    @AuraEnabled(cacheable=true)
    public static Map<String, Decimal> calculateMonthlyPayment(
        Decimal homePrice,
        Decimal downPaymentPercent,
        Decimal interestRate,
        Integer loanTerm
    ) {

        if (homePrice == null) homePrice = 0;
        if (downPaymentPercent == null) downPaymentPercent = 0;
        if (interestRate == null) interestRate = 0;
        if (loanTerm == null) loanTerm = 30;

        Decimal downPaymentAmount = homePrice * (downPaymentPercent / 100);
        Decimal loanAmount = homePrice - downPaymentAmount;

        Decimal monthly = calculateMonthlyPayment(
            loanAmount,
            interestRate,
            loanTerm
        );

        Decimal totalInterest =
            (monthly * loanTerm * 12) - loanAmount;

        Decimal ltv = (homePrice > 0)
            ? (loanAmount / homePrice) * 100
            : 0;

        Map<String, Decimal> res = new Map<String, Decimal>();
        res.put('monthlyPayment', monthly);
        res.put('principal', loanAmount);
        res.put('interest', totalInterest);
        res.put('ltv', ltv);

        return res;
    }

    // =====================================================
    // CREATE MORTGAGE APPLICATION (NO SCHEMA CHANGES)
    // =====================================================
    @AuraEnabled
    public static Id createMortgageApplication(
        Id propertyId,
        Id buyerId,
        Decimal homePrice,
        Decimal downPaymentPercent,
        Decimal interestRate,
        Integer loanTerm
    ) {

        if (propertyId == null || buyerId == null) {
            throw new AuraHandledException('Property and Buyer are required');
        }

        Decimal downPaymentAmount = homePrice * (downPaymentPercent / 100);
        Decimal loanAmount = homePrice - downPaymentAmount;

        Decimal monthlyPayment = calculateMonthlyPayment(
            loanAmount,
            interestRate,
            loanTerm
        );

        Decimal totalInterest =
            (monthlyPayment * loanTerm * 12) - loanAmount;

        Decimal ltv = (homePrice > 0)
            ? (loanAmount / homePrice) * 100
            : 0;

        Mortgage_Application__c app = new Mortgage_Application__c();

        // ONLY EXISTING FIELDS (SAFE)
        app.Property__c = propertyId;
        app.Buyer__c = buyerId;
        app.Application_Date__c = Date.today();

        app.Down_Payment__c = downPaymentAmount;
        app.Interest_Rate__c = interestRate;
        app.Loan_Amount__c = loanAmount;
        app.Term_years__c = loanTerm;
        app.Status__c = 'Submitted';

        insert app;

        return app.Id;
    }

    // =====================================================
    // GAP 11 — AMORTIZATION ENGINE (Apex REQUIRED FIX)
    // =====================================================
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Decimal>> generateAmortizationSchedule(
        Decimal loanAmount,
        Decimal rate,
        Integer termYears
    ) {

        List<Map<String, Decimal>> schedule = new List<Map<String, Decimal>>();

        Decimal monthly = calculateMonthlyPayment(loanAmount, rate, termYears);
        Decimal balance = loanAmount;
        Decimal r = rate / 100 / 12;

        for (Integer i = 1; i <= termYears * 12; i++) {

            Decimal interest = balance * r;
            Decimal principal = monthly - interest;
            balance = balance - principal;

            Map<String, Decimal> row = new Map<String, Decimal>();
            row.put('month', i);
            row.put('payment', monthly);
            row.put('interest', interest);
            row.put('principal', principal);
            row.put('balance', balance > 0 ? balance : 0);

            schedule.add(row);
        }

        return schedule;
    }

    // =====================================================
    // GAP 12 — COMPARISON MODE (3 SCENARIOS)
    // =====================================================
    public class MortgageScenario {
        @AuraEnabled public Decimal rate;
        @AuraEnabled public Integer term;
        @AuraEnabled public Decimal monthly;
    }

    @AuraEnabled(cacheable=true)
    public static List<MortgageScenario> compareScenarios(
        Decimal loanAmount
    ) {

        List<MortgageScenario> results = new List<MortgageScenario>();

        Decimal[] rates = new Decimal[]{3.5, 5.0, 6.5};
        Integer[] terms = new Integer[]{15, 20, 30};

        for (Decimal r : rates) {
            for (Integer t : terms) {

                MortgageScenario s = new MortgageScenario();
                s.rate = r;
                s.term = t;
                s.monthly = calculateMonthlyPayment(loanAmount, r, t);

                results.add(s);
            }
        }

        return results;
    }

    // =====================================================
    // GAP 13 — AFFORDABILITY FIX (OVERLOAD, SAFE)
    // =====================================================
    @AuraEnabled(cacheable=true)
    public static Decimal calculateAffordability(
        Decimal grossIncome,
        Decimal monthlyDebts,
        Decimal downPayment,
        Decimal rate,
        Integer term
    ) {

        Decimal base = calculateAffordability(grossIncome, monthlyDebts);

        Decimal adjustment = (downPayment != null) ? (downPayment / 1000) * 10 : 0;

        return base + adjustment;
    }

    // =====================================================
    // GAP 14 — CSV EXPORT
    // =====================================================
    @AuraEnabled
    public static String exportAmortizationCSV(
        Decimal loanAmount,
        Decimal rate,
        Integer term
    ) {

        List<Map<String, Decimal>> data =
            generateAmortizationSchedule(loanAmount, rate, term);

        String csv = 'Month,Payment,Interest,Principal,Balance\n';

        for (Map<String, Decimal> row : data) {
            csv += row.get('month') + ',' +
                   row.get('payment') + ',' +
                   row.get('interest') + ',' +
                   row.get('principal') + ',' +
                   row.get('balance') + '\n';
        }

        return csv;
    }
}