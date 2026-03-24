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

private static void generateRecords(List<Contact> contacts) {
    Map<String, Grant_Option__mdt> metaMap = new Map<String, Grant_Option__mdt>();
    for (Grant_Option__mdt m : [SELECT Label, Amount__c, Months__c FROM Grant_Option__mdt]) {
        metaMap.put(m.Label, m);
    }

    Set<Id> contactIds = new Map<Id, Contact>(contacts).keySet();

    // 1. Get Disbursed History (How many months and how much money already paid)
    Map<Id, Decimal> receivedAmountMap = new Map<Id, Decimal>();
    Map<Id, Integer> monthsPaidMap = new Map<Id, Integer>();
    
    for (Grant_Disbursed__c gd : [SELECT Grant_Applicant__c, Amount_to_be_disbursed__c 
                                  FROM Grant_Disbursed__c 
                                  WHERE Grant_Applicant__c IN :contactIds AND Disbursed_Date__c <= TODAY]) {
        Decimal currentAmt = receivedAmountMap.containsKey(gd.Grant_Applicant__c) ? receivedAmountMap.get(gd.Grant_Applicant__c) : 0;
        receivedAmountMap.put(gd.Grant_Applicant__c, currentAmt + gd.Amount_to_be_disbursed__c);
        
        Integer currentMonths = monthsPaidMap.containsKey(gd.Grant_Applicant__c) ? monthsPaidMap.get(gd.Grant_Applicant__c) : 0;
        monthsPaidMap.put(gd.Grant_Applicant__c, currentMonths + 1);
    }

    // 2. Clear FUTURE records only
    delete [SELECT Id FROM Grant_Disbursed__c WHERE Grant_Applicant__c IN :contactIds AND Disbursed_Date__c > TODAY];

    List<Grant_Disbursed__c> toInsert = new List<Grant_Disbursed__c>();

    for (Contact con : contacts) {
        Grant_Option__mdt rules = metaMap.get(con.Support_Option__c);
        if (rules == null) continue;

        Decimal amtReceived = receivedAmountMap.containsKey(con.Id) ? receivedAmountMap.get(con.Id) : 0;
        Integer monthsPaid = monthsPaidMap.containsKey(con.Id) ? monthsPaidMap.get(con.Id) : 0;
        
        Decimal newOptionTotal = rules.Amount__c * rules.Months__c;
        Integer totalMonthsForNewOption = (Integer)rules.Months__c;

        // US3: Blocker Logic
        if (amtReceived > newOptionTotal) {
            con.addError('Cannot change option: Total received (SGD ' + amtReceived + ') exceeds new option total (SGD ' + newOptionTotal + ').');
            continue;
        }

        // US3: Redistribution Math
        Decimal remainingFunds = newOptionTotal - amtReceived;
        Integer remainingMonths = totalMonthsForNewOption - monthsPaid;

        if (remainingMonths > 0) {
            Decimal monthlyAmt = remainingFunds / remainingMonths;
            Date nextDate = Date.today().addMonths(1).toStartOfMonth();

            for (Integer i = 0; i < remainingMonths; i++) {
                toInsert.add(new Grant_Disbursed__c(
                    Grant_Applicant__c = con.Id,
                    Amount_to_be_disbursed__c = monthlyAmt,
                    Grant_is_disbursed__c = true,
                    Disbursed_Date__c = nextDate.addMonths(i)
                ));
            }
        }
    }

    // System.debug('DEBUG: Number of records to insert: ' + toInsert.size());
    if (!toInsert.isEmpty()) {
        insert toInsert;
    }
  }
}
