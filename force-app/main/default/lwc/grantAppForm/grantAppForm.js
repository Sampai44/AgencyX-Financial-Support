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
        // Collect data from inputs
        const fields = {};
        this.template.querySelectorAll('lightning-input, lightning-combobox').forEach(input => {
            fields[input.label] = input.value; 
        });

        // Map UI fields to Salesforce API names
        const contactRecord = {
            FirstName: this.template.querySelector('[data-id="FirstName"]').value,
            LastName: this.template.querySelector('[data-id="LastName"]').value,
            Phone: this.template.querySelector('[data-id="Phone"]').value,
            Mailing_Postal_Code__c: this.template.querySelector('[data-id="PostalCode"]').value,
            Monthly_Income__c: this.template.querySelector('[data-id="Income"]').value,
            Support_Option__c: this.template.querySelector('[data-id="Option"]').value
        };

        submitApplication({ con: contactRecord })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Success', message: 'Application Sent!', variant: 'success' }));
            })
            .catch(error => {
                console.error(error);
            });
    }
}
