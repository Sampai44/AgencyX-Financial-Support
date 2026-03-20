public without sharing class GrantApplicationController {
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
