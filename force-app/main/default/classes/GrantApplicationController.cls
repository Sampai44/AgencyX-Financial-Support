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
            // The Trigger now handles the Income check and Disbursement creation!
            // We just need to Upsert the Contact here.
            
            List<Contact> existing = [SELECT Id FROM Contact WHERE Phone = :con.Phone LIMIT 1];
            if (!existing.isEmpty()) {
                con.Id = existing[0].Id;
                update con;
                return 'Existing Contact Updated Successfully';
            } else {
                insert con;
                return 'New Application Created Successfully';
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
