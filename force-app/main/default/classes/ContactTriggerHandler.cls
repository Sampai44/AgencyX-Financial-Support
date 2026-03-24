public without sharing class ContactTriggerHandler {
    
    // Entry point called by the Trigger for both NEW and UPDATED contacts
    public static void handleDisbursements(List<Contact> newList, Map<Id, Contact> oldMap) {
        List<Contact> eligibleContacts = new List<Contact>();

        for (Contact con : newList) {
            // US4: If income is >= 2000, block the record save
            // System.Label.Ineligible_Income_Error allows Admins to manage this text in Setup
            if (con.Income__c != null && con.Income__c >= 2000) {
                con.Income__c.addError(System.Label.Ineligible_Income_Error);
            } 
            // US2/US4: If eligible (Income < 2000), check if we need to generate records
            else if (con.Income__c != null && con.Support_Option__c != null) {
                
                // US3/US4: Only process if it is a new Contact or the Support Option has changed
                if (oldMap == null || con.Support_Option__c != oldMap.get(con.Id).Support_Option__c) {
                    eligibleContacts.add(con);
                }
            }
        }

        // Only move to record generation if there are eligible contacts to process
        if (!eligibleContacts.isEmpty()) {
            generateRecords(eligibleContacts);
        }
    }

    // Creates the disbursement records in bulk to support US4 CSV uploads
    private static void generateRecords(List<Contact> contacts) {
        // BULKIFICATION: Query all Custom Metadata rules once to avoid hitting limits
        Map<String, Grant_Option__mdt> metaMap = new Map<String, Grant_Option__mdt>();
        for (Grant_Option__mdt m : [SELECT Label, Amount__c, Months__c FROM Grant_Option__mdt]) {
            metaMap.put(m.Label, m);
        }

        List<Grant_Disbursed__c> toInsert = new List<Grant_Disbursed__c>();
        Set<Id> contactIds = new Map<Id, Contact>(contacts).keySet();

        // US3: Clear any existing future disbursement records for these contacts before creating new ones
        // Using 'IN :contactIds' ensures this is bulk-safe for up to 200 records
        delete [SELECT Id FROM Grant_Disbursed__c 
                WHERE Grant_Applicant__c IN :contactIds 
                AND Disbursed_Date__c > TODAY];

        for (Contact con : contacts) {
            // Retrieve the specific rules from our metadata map
            Grant_Option__mdt rules = metaMap.get(con.Support_Option__c);
            if (rules == null) continue; 

            Integer months = (Integer)rules.Months__c;
            Decimal amount = rules.Amount__c;
            
            // US2: First disbursement starts on the 1st day of the next month
            Date nextDate = Date.today().addMonths(1).toStartOfMonth();

            // Loop to build the schedule for this specific contact
            for (Integer i = 0; i < months; i++) {
                toInsert.add(new Grant_Disbursed__c(
                    Grant_Applicant__c = con.Id,
                    Amount_to_be_disbursed__c = amount,
                    Grant_is_disbursed__c = true,
                    Disbursed_Date__c = nextDate.addMonths(i)
                ));
            }
        }

        // System.debug('DEBUG: Number of records to insert: ' + toInsert.size());
        // BULKIFICATION: Perform one single DML insert for all records across all contacts
        if (!toInsert.isEmpty()) {
            insert toInsert;
        }
    }
}