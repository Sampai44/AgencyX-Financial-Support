public without sharing class GrantApplicationController {
    // Fetches options for the LWC dropdown
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getSupportOptions() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        
        // Query the Metadata
        for (Grant_Option__mdt m : [SELECT Label, Amount__c, Months__c 
                                    FROM Grant_Option__mdt 
                                    ORDER BY Label ASC]) {
            Map<String, String> opt = new Map<String, String>();
            // What the user sees
            opt.put('label', m.Label + ': SGD ' + m.Amount__c + ' (' + m.Months__c + ' months)');
            // What is saved to the Contact record 
            opt.put('value', m.Label); 
            options.add(opt);
        }
        return options;
    }

    @AuraEnabled
public static String submitApplication(Contact con) {
    try {
        List<Contact> existing = [SELECT Id, Support_Option__c, Income__c FROM Contact WHERE Phone = :con.Phone LIMIT 1];
        
        if (!existing.isEmpty()) {
            // MERGE: Update the existing record's fields with the new ones
            Contact toUpdate = existing[0];
            toUpdate.FirstName = con.FirstName;
            toUpdate.LastName = con.LastName;
            toUpdate.Mailing_Postal_Code__c = con.Mailing_Postal_Code__c;
            toUpdate.Income__c = con.Income__c;
            toUpdate.Support_Option__c = con.Support_Option__c; 

            update toUpdate; 
            return 'Success: Existing Application Updated';
        } else {
            insert con;
            return 'Success: New Application Created';
        }
    } catch (Exception e) {
        throw new AuraHandledException(e.getMessage());
    }
  }
}