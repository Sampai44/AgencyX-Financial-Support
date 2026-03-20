public without sharing class GrantApplicationController {
    @AuraEnabled
    public static String submitApplication(Contact con) {
        try {
            // 1. Check Eligibility FIRST
            if (con.Income__c >= 2000) {
                return 'Ineligible: Income must be less than SGD 2000';
            }

            // 2. Handle Contact (Upsert based on Phone)
            List<Contact> existing = [SELECT Id FROM Contact WHERE Phone = :con.Phone LIMIT 1];
            if (!existing.isEmpty()) {
                con.Id = existing[0].Id;
                update con;
            } else {
                insert con;
            }

            // 3. Create Disbursement Records
            createDisbursements(con.Id, con.Support_Option__c);
            
            return 'Application Successful';
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static void createDisbursements(Id contactId, String optionName) {
    // 1. Look up the rules from the Metadata table
    // It finds the row where the Label matches the user's choice
    Grant_Option__mdt rules = [
        SELECT Amount__c, Months__c 
        FROM Grant_Option__mdt 
        WHERE Label = :optionName 
        LIMIT 1
    ];

    // 2. Use the values from the Metadata record
    Decimal amount = rules.Amount__c;
    Integer months = (Integer)rules.Months__c;

    // 3. Create the records as usual
    List<Grant_Disbursed__c> recordsToInsert = new List<Grant_Disbursed__c>();
    Date nextDisburseDate = Date.today().addMonths(1).toStartOfMonth();

        for (Integer i = 0; i < months; i++) {
            recordsToInsert.add(new Grant_Disbursed__c(
                Grant_Applicant__c = contactId,
                Amount_to_be_disbursed__c = amount,
                Grant_is_disbursed__c = true,
                Disbursed_Date__c = nextDisburseDate.addMonths(i)
            ));
        }
        insert recordsToInsert;
    }

}

