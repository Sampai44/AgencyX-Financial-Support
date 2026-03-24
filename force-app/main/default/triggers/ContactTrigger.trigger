trigger ContactTrigger on Contact (after insert, after update) {
    // Calls the handler whenever a Contact is created or updated
    ContactTriggerHandler.handleDisbursements(Trigger.new, Trigger.oldMap);
}