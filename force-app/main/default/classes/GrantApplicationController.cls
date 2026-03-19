public with sharing class GrantApplicationController {
    @AuraEnabled
    public static String submitApplication(Contact con) {
        try {
            // Check if phone number (65xxxxxxxx) already exists
            List<Contact> existing = [SELECT Id FROM Contact WHERE Phone = :con.Phone LIMIT 1];
            
            if (!existing.isEmpty()) {
                con.Id = existing[0].Id;
                update con;
                return 'Existing Contact Updated';
            } else {
                insert con;
                return 'New Contact Created';
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }
}
