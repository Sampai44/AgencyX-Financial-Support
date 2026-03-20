@isTest
private class ContactTriggerTest {

    @testSetup
    static void setupData() {
        // Note to self: Custom Metadata records are already visible in tests, NO NEED to create 
    }

    // 2. Test Success: New Application (Positive Path)
    @isTest
    static void testNewEligibleApplication() {
        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'Success',
            Phone = '6512345678',
            Income__c = 1500,
            Support_Option__c = 'Option 1' 
        );

        Test.startTest();
        insert con;
        Test.stopTest();

        // ASSERT: Check that 3 disbursement records were created (Option 1 = 3 months)
        List<Grant_Disbursed__c> grants = [SELECT Id FROM Grant_Disbursed__c WHERE Grant_Applicant__c = :con.Id];
        Assert.areEqual(3, grants.size(), 'Should have created 3 disbursement records');
    }

    // 3. Test Failure: High Income (Negative Path)
    @isTest
    static void testIneligibleIncome() {
        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'Fail',
            Phone = '6599998888',
            Income__c = 3000, // Above limit
            Support_Option__c = 'Option 1'
        );

        Test.startTest();
        try {
            insert con;
            Assert.fail('The trigger should have blocked this record due to high income.');
        } catch (DmlException e) {
            // ASSERT: Verify the custom label error message is thrown
            Assert.isTrue(e.getMessage().contains(System.Label.Ineligible_Income_Error), 'Error message should match the Custom Label');
        }
        Test.stopTest();
    }

    // 4. Test Bulk: 200 Records (Governor Limit Check)
    @isTest
    static void testBulkUpload() {
        List<Contact> bulkContacts = new List<Contact>();
        for(Integer i=0; i<200; i++) {
            bulkContacts.add(new Contact(
                FirstName = 'Bulk',
                LastName = 'User ' + i,
                Phone = '65' + String.valueOf(10000000 + i),
                Income__c = 1000,
                Support_Option__c = 'Option 1'
            ));
        }

        Test.startTest();
        insert bulkContacts;
        Test.stopTest();

        // ASSERT: 200 contacts * 3 records = 600 total disbursements
        Integer count = [SELECT COUNT() FROM Grant_Disbursed__c];
        Assert.areEqual(600, count, 'Bulk upload should process 200 contacts successfully');
    }
}
