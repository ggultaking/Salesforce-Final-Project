public class MortgageCalculatorService {

    public static Decimal calculateMonthlyPayment(
        Decimal loanAmount,
        Decimal annualRate,
        Integer termYears
    ) {
        Double r = annualRate.doubleValue() / 100.0 / 12.0;
        Integer n = termYears * 12;

        if (r == 0) {
            return loanAmount / n;
        }

        Double base = 1 + r;

        Double pow = Math.pow(base, n);

        Double payment =
            loanAmount.doubleValue() *
            (r * pow) /
            (pow - 1);

        return Decimal.valueOf(payment).setScale(2);
    }

    public static Decimal calculateAffordability(
        Decimal income,
        Decimal debts,
        Decimal downPayment,
        Decimal rate,
        Integer term
    ) {
        Decimal monthlyIncome = income / 12;
        Decimal maxPayment = monthlyIncome * 0.43 - debts;

        return maxPayment * 12;
    }
}