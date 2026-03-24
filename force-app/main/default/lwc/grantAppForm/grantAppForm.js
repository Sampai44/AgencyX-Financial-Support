import { LightningElement } from 'lwc';
import submitApplication from '@salesforce/apex/GrantApplicationController.submitApplication';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class GrantAppForm extends LightningElement {
    options = [
        { label: 'Option 1: $500 (3 months)', value: 'Option 1' },
        { label: 'Option 2: $300 (6 months)', value: 'Option 2' },
        { label: 'Option 3: $200 (12 months)', value: 'Option 3' },
    ];

   
    handleSubmit() {
    // 1. CHECK VALIDITY FIRST
    const allValid = [
        ...this.template.querySelectorAll('lightning-input'),
        ...this.template.querySelectorAll('lightning-combobox')
    ].reduce((validSoFar, inputCmp) => {
        inputCmp.reportValidity(); // This shows the red error messages
        return validSoFar && inputCmp.checkValidity(); // This checks if the field is actually okay
    }, true);

    // 2. STOP if any field is red/invalid
    if (!allValid) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message: 'Please fix the errors on the form before submitting.',
            variant: 'error'
        }));
        return; 
    }

    // 3. MAP YOUR DATA 
    const contactRecord = {
        FirstName: this.template.querySelector('[data-id="FirstName"]').value,
        LastName: this.template.querySelector('[data-id="LastName"]').value,
        Phone: this.template.querySelector('[data-id="Phone"]').value,
        Mailing_Postal_Code__c: this.template.querySelector('[data-id="PostalCode"]').value,
        Income__c: this.template.querySelector('[data-id="Income"]').value,
        Support_Option__c: this.template.querySelector('[data-id="Option"]').value
    };

    // 4. CALL APEX
    submitApplication({ con: contactRecord })
        .then((result) => {
            // Check if result contains 'Success'
            if (result.includes('Success')) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: result,
                    variant: 'success'
                }));
            } else {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: result, // This will catch the "Invalid" or "Ineligible" messages
                    variant: 'error'
                }));
            }
        })
        .catch((error) => {
            // This catches system crashes (DML exceptions, etc.)
            this.dispatchEvent(new ShowToastEvent({
                title: 'System Error',
                message: error.body.message,
                variant: 'error'
            }));
        });
    }
}

