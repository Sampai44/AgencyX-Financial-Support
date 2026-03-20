public WITHOUT SHARING class GrantApplicationController {
    
    @AuraEnabled
    public static String submitApplication(Contact con) {
        try {
            // 1. Eligibility Check
            if (con.Income__c >= 2000) {
                return 'Ineligible: Income must be less than SGD 2000';
            }

            // 2. Identify if New or Existing
            List<Contact> existingList = [SELECT Id FROM Contact WHERE Phone = :con.Phone LIMIT 1];
            
            if (!existingList.isEmpty()) {
                Id contactId = existingList[0].Id;
                con.Id = contactId;
                update con; // Update personal info (Name, Postal Code, etc.)
                
                // 3. Handle the Support Option Change Logic
                return handleOptionChange(contactId, con.Support_Option__c);
            } else {
                insert con;
                createDisbursements(con.Id, con.Support_Option__c);
                return 'New Application Successful';
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static String handleOptionChange(Id contactId, String newOptionName) {
        // A. Get New Option details from Metadata
        Grant_Option__mdt newRules = [SELECT Amount__c, Months__c FROM Grant_Option__mdt WHERE Label = :newOptionName LIMIT 1];
        Decimal newTotalValue = newRules.Amount__c * newRules.Months__c;

        // B. Calculate how much has ALREADY been disbursed (Spent)
        // We assume records with dates in the past/today are spent
        AggregateResult[] spentData = [SELECT SUM(Amount_to_be_disbursed__c) amt, COUNT(Id) cnt 
                                       FROM Grant_Disbursed__c 
                                       WHERE Grant_Applicant__c = :contactId 
                                       AND Disbursed_Date__c <= TODAY];
        
        Decimal totalSpent = (Decimal)spentData[0].get('amt');
        if(totalSpent == null) totalSpent = 0;
        
        Integer monthsSpent = (Integer)spentData[0].get('cnt');

        // C. VALIDATION: Total Spent vs New Total
        if (totalSpent > newTotalValue) {
            return 'Invalid Option: Total already received (SGD ' + totalSpent + ') exceeds the new option limit (SGD ' + newTotalValue + ').';
        }

        // D. Delete future records to make room for new ones
        delete [SELECT Id FROM Grant_Disbursed__c WHERE Grant_Applicant__c = :contactId AND Disbursed_Date__c > TODAY];

        // E. CALCULATE REMAINING
        Decimal remainingFunds = newTotalValue - totalSpent;
        Integer remainingMonths = (Integer)newRules.Months__c - monthsSpent;

        if (remainingMonths > 0) {
            Decimal newMonthlyRate = remainingFunds / remainingMonths;
            insertNewDisbursements(contactId, remainingMonths, newMonthlyRate);
        }

        return 'Support Option Updated Successfully';
    }

    private static void insertNewDisbursements(Id contactId, Integer months, Decimal amount) {
        List<Grant_Disbursed__c> toInsert = new List<Grant_Disbursed__c>();
        Date nextDate = Date.today().addMonths(1).toStartOfMonth();

        for (Integer i = 0; i < months; i++) {
            toInsert.add(new Grant_Disbursed__c(
                Grant_Applicant__c = contactId,
                Amount_to_be_disbursed__c = amount,
                Grant_is_disbursed__c = true,
                Disbursed_Date__c = nextDate.addMonths(i)
            ));
        }
        insert toInsert;
    }

    // Initial creation for brand new applicants
    private static void createDisbursements(Id contactId, String optionName) {
        Grant_Option__mdt rules = [SELECT Amount__c, Months__c FROM Grant_Option__mdt WHERE Label = :optionName LIMIT 1];
        insertNewDisbursements(contactId, (Integer)rules.Months__c, rules.Amount__c);
    }
}