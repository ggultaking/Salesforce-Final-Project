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
        Double payment = loanAmount.doubleValue() * (r * pow) / (pow - 1);

        return Decimal.valueOf(payment).setScale(2);
    }

    // ==============================
    // GET BUYER ID (for LWC)
    // ==============================
    @AuraEnabled(cacheable=true)
    public static Id getBuyerId() {

        Id userId = UserInfo.getUserId();

        List<Buyer__c> buyers = [
            SELECT Id
            FROM Buyer__c
            WHERE Assigned_Agent__c = :userId
            LIMIT 1
        ];

        if (buyers.isEmpty()) {
            return null;
        }

        return buyers[0].Id;
    }

    // ==============================
    // EXPORT AMORTIZATION (base64 CSV)
    // ==============================
    @AuraEnabled
    public static String exportAmortization(List<Map<String, Object>> schedule) {

        String csv = 'Month,Payment,Interest,Principal,Balance\n';

        for (Map<String, Object> row : schedule) {
            csv += String.valueOf(row.get('month')) + ',' +
                   String.valueOf(row.get('payment')) + ',' +
                   String.valueOf(row.get('interest')) + ',' +
                   String.valueOf(row.get('principal')) + ',' +
                   String.valueOf(row.get('balance')) + '\n';
        }

        return EncodingUtil.base64Encode(Blob.valueOf(csv));
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
    // LWC WRAPPER — MONTHLY PAYMENT
    // =====================================================
    @AuraEnabled(cacheable=true)
    public static Map<String, Decimal> calculateMonthlyPayment(
        Decimal homePrice,
        Decimal downPaymentPercent,
        Decimal interestRate,
        Integer loanTerm
    ) {
        if (homePrice == null)          homePrice = 0;
        if (downPaymentPercent == null) downPaymentPercent = 0;
        if (interestRate == null)       interestRate = 0;
        if (loanTerm == null)           loanTerm = 30;

        Decimal downPaymentAmount = homePrice * (downPaymentPercent / 100);
        Decimal loanAmount = homePrice - downPaymentAmount;

        Decimal monthly = calculateMonthlyPayment(loanAmount, interestRate, loanTerm);

        Decimal totalInterest = (monthly * loanTerm * 12) - loanAmount;

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
    // CREATE MORTGAGE APPLICATION
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

        if (homePrice == null)          homePrice = 0;
        if (downPaymentPercent == null) downPaymentPercent = 0;
        if (interestRate == null)       interestRate = 0;
        if (loanTerm == null)           loanTerm = 30;

        Decimal downPaymentAmount = homePrice * (downPaymentPercent / 100);
        Decimal loanAmount = homePrice - downPaymentAmount;

        Decimal monthlyPayment = calculateMonthlyPayment(loanAmount, interestRate, loanTerm);
        Decimal totalInterest  = (monthlyPayment * loanTerm * 12) - loanAmount;
        Decimal ltv = (homePrice > 0) ? (loanAmount / homePrice) * 100 : 0;

        Mortgage_Application__c app = new Mortgage_Application__c();

        app.Property__c       = propertyId;
        app.Buyer__c          = buyerId;
        app.Application_Date__c = Date.today();
        app.Down_Payment__c   = downPaymentAmount;
        app.Interest_Rate__c  = interestRate;
        app.Loan_Amount__c    = loanAmount;
        app.Term_years__c     = loanTerm;
        app.Status__c         = 'Submitted';

        insert app;

        return app.Id;
    }

    // =====================================================
    // AMORTIZATION ENGINE
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

            Decimal interest  = balance * r;
            Decimal principal = monthly - interest;
            balance = balance - principal;

            Map<String, Decimal> row = new Map<String, Decimal>();
            row.put('month',     i);
            row.put('payment',   monthly);
            row.put('interest',  interest);
            row.put('principal', principal);
            row.put('balance',   balance > 0 ? balance : 0);

            schedule.add(row);
        }

        return schedule;
    }

    // =====================================================
    // COMPARISON MODE (3 SCENARIOS)
    // =====================================================
    public class MortgageScenario {
        @AuraEnabled public Decimal rate;
        @AuraEnabled public Integer term;
        @AuraEnabled public Decimal monthly;
    }

    @AuraEnabled(cacheable=true)
    public static List<MortgageScenario> compareScenarios(Decimal loanAmount) {

        List<MortgageScenario> results = new List<MortgageScenario>();

        Decimal[] rates = new Decimal[]{3.5, 5.0, 6.5};
        Integer[] terms = new Integer[]{15, 20, 30};

        for (Decimal r : rates) {
            for (Integer t : terms) {
                MortgageScenario s = new MortgageScenario();
                s.rate    = r;
                s.term    = t;
                s.monthly = calculateMonthlyPayment(loanAmount, r, t);
                results.add(s);
            }
        }

        return results;
    }

    // =====================================================
    // AFFORDABILITY OVERLOAD (with down payment)
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
    // CSV EXPORT (plain text, no base64)
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