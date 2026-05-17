@isTest
public class MortgageCalculatorServiceTest {

    @isTest
    static void testMonthlyPayment() {

        Decimal result = MortgageCalculatorService.calculateMonthlyPayment(
            100000,
            10,
            10
        );

        System.assert(result > 0);
    }

    @isTest
    static void testAffordability() {

        Decimal result = MortgageCalculatorService.calculateAffordability(
            60000,
            500,
            20000,
            10,
            10
        );

        System.assert(result > 0);
    }
}