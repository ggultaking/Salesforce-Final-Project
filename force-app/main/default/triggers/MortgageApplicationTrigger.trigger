trigger MortgageApplicationTrigger on Mortgage_Application__c ( before insert,
    before update) {
         for (Mortgage_Application__c m : Trigger.new) {

        // BASIC VALIDATION PLACEHOLDER

        if (m.Loan_Amount__c != null && m.Loan_Amount__c <= 0) {
            m.addError('Loan amount must be greater than 0');
        }

        if (m.Interest_Rate__c != null && m.Interest_Rate__c < 0) {
            m.addError('Interest rate cannot be negative');
        }
    }

}