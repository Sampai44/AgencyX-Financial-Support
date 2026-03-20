public without sharing class ContactTriggerHandler {
    
    public static void handleDisbursements(List<Contact> newList, Map<Id, Contact> oldMap) {
        List<Contact> eligibleContacts = new List<Contact>();

        for (Contact con : newList) {
            // 1. Eligibility Check (Income must be < 2000)
            if (con.Income__c < 2000 && con.Support_Option__c != null) {
                
                // 2. Check if this is a NEW contact OR if an EXISTING contact changed their option
                if (oldMap == null || con.Support_Option__c != oldMap.get(con.Id).Support_Option__c) {
                    eligibleContacts.add(con);
                }
            }
        }

        if (!eligibleContacts.isEmpty()) {
            generateRecords(eligibleContacts);
        }
    }

    private static void generateRecords(List<Contact> contacts) {
        // BULKIFIED: Query all metadata once
        Map<String, Grant_Option__mdt> metaMap = new Map<String, Grant_Option__mdt>();
        for (Grant_Option__mdt m : [SELECT Label, Amount__c, Months__c FROM Grant_Option__mdt]) {
            metaMap.put(m.Label, m);
        }

        List<Grant_Disbursed__c> toInsert = new List<Grant_Disbursed__c>();
        Set<Id> contactIds = new Map<Id, Contact>(contacts).keySet();

        // BULKIFIED: Delete future records for these contacts in one go
        delete [SELECT Id FROM Grant_Disbursed__c WHERE Grant_Applicant__c IN :contactIds AND Disbursed_Date__c > TODAY];

        for (Contact con : contacts) {
            Grant_Option__mdt rules = metaMap.get(con.Support_Option__c);
            if (rules == null) continue;

            Integer months = (Integer)rules.Months__c;
            Decimal amount = rules.Amount__c;
            Date nextDate = Date.today().addMonths(1).toStartOfMonth();

            for (Integer i = 0; i < months; i++) {
                toInsert.add(new Grant_Disbursed__c(
                    Grant_Applicant__c = con.Id,
                    Amount_to_be_disbursed__c = amount,
                    Grant_is_disbursed__c = true,
                    Disbursed_Date__c = nextDate.addMonths(i)
                ));
            }
        }

        if (!toInsert.isEmpty()) {
            insert toInsert; // One DML for all 200+ records
        }
    }
}
