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
                con.Id = existing.Id;
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

    private static void createDisbursements(Id contactId, String option) {
        List<Grant_Disbursed__c> recordsToInsert = new List<Grant_Disbursed__c>();
        Integer months = 0;
        Decimal amount = 0;

        // Configuration 
        if (option == 'Option 1') { months = 3; amount = 500; }
        else if (option == 'Option 2') { months = 6; amount = 300; }
        else if (option == 'Option 3') { months = 12; amount = 200; }

        // Logic for "1st day of next month"
        Date nextDisburseDate = Date.today().addMonths(1).toStartOfMonth();

        for (Integer i = 0; i < months; i++) {
            recordsToInsert.add(new Grant_Disbursed__c(
                Grant_Applicant__c = contactId,
                Amount_to_be_disbursed__c = amount,
                Grant_is_disbursed__c = true,
                Disbursed_Date__c = nextDisburseDate.addMonths(i)
            ));
        }

        if (!recordsToInsert.isEmpty()) {
            insert recordsToInsert;
        }
    }
}
