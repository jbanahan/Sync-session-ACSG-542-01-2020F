require 'open_chain/workflow_decider'
require 'open_chain/workflow_tester/attachment_type_workflow_test'
require 'open_chain/workflow_tester/multi_state_workflow_test'
require 'open_chain/workflow_tester/model_field_workflow_test'
require 'open_chain/workflow_tester/survey_complete_workflow_test'
require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberVendorWorkflowDecider
  extend OpenChain::WorkflowDecider
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport

  def self.base_object_class
    Company
  end

  def self.workflow_name
    'Vendor Setup'
  end

  def self.skip? company
    !company.vendor?
  end

  def self.do_workflow! vendor, workflow_inst, user
    vendor_create = Group.use_system_group 'LL-VENDOR-CREATE', 'Vendor Creators'
    vendor_employees = Group.use_system_group 'LL-VENDOR-EMPL', 'Vendor Employees'
    merch_managers = Group.use_system_group 'LL-MERCH-MANAGERS', 'Merchandising Managers'
    # vendor = Group.use_system_group 'LL-VENDOR', 'Vendor'
    
    # SUBSTITUTE THIS FOR THE TEST BELOW WITH THE SAME VARIABLE NAME 
    vendor_intake_survey = first_or_create_test! workflow_inst, 
      'LL-INTAKE',
      OpenChain::WorkflowTester::SurveyCompleteWorkflowTest,
      'Rate vendor intake survey',
      vendor_create,
      {'survey_code'=>'LL-INTAKE','survey_rating'=>'Proceed'},
      nil,
      view_path(vendor)
    if vendor_intake_survey.test! 
      vendor_quote_sheet = first_or_create_attachment_test! 'Vendor Quote Sheet',
        workflow_inst,
        'LL-VENDOR-QUOTE-SHEET', 
        'Attach Quote Sheet', 
        vendor_employees, 
        nil,
        view_path(vendor)
      if vendor_quote_sheet.test!
        #NEED QUOTE SHEET APPROVAL
        quote_sheet_approval = true
        if quote_sheet_approval
          #substitute this with a ModelField test for drop downs [blank,yes,no] for all product type categories
          # also require expected countries of origin
          product_type_fields = first_or_create_test! workflow_inst,
            'LL-PROD-TYPES',
            OpenChain::WorkflowTester::MultiStateWorkflowTest,
            'Complete all product category fields.',
            vendor_create,
            {'state_options'=>['Placeholder']},
            nil,
            view_path(vendor)
          if product_type_fields.test!

            # Conditional logic here provided by Chris to prompt his team whether additional addendum documents and forms are required and if yes
            # add subtasks to require them

            # 3.5 - 3.7 are acknowledgement tasks based on product type.  Chris to provide final matrix 

            # CREATE MULTI STATE WORKFLOW TEST THAT TESTS IF Vendor has acknowldeged latest Supplier Ref Manual from FORMS and
            # clears the acknowledgement if the form has been updated after the acknowledgment
            sup_ref_ack = first_or_create_test! workflow_inst,
              'LL-SUP-REF-ACK',
              OpenChain::WorkflowTester::MultiStateWorkflowTest,
              'Review Supplier Reference Manual on Forms tab',
              vendor_employees,
              {'state_options'=>['Acknowledge']},
              due_in_days(7),
              view_path(vendor)
            final_vendor_agree = first_or_create_attachment_test! 'Signed Vendor Agreement',
              workflow_inst,
              'LL-FIN-VEN-AGR',
              'Attach Signed Vendor Agreement', 
              vendor_create, 
              nil,
              view_path(vendor)
            cert_of_insurance = first_or_create_test! workflow_inst,
              'LL-CERT-INS',
              OpenChain::WorkflowTester::AttachmentTypeWorkflowTest,
              'Attach Certificate of Insurance',
              vendor_employees,
              {'attachment_type'=>'Certificate of Insurance'},
              nil,
              view_path(vendor)

            # require business license attachment
            business_license = first_or_create_attachment_test! 'Business License', 
              workflow_inst,
              'LL-BUS-LIC',
              'Attach Business License',
              vendor_employees,
              nil,
              view_path(vendor)

            # issue Lisa's triage survey

            if final_vendor_agree.test! && cert_of_insurance.test!
              merch_vend_agree_approve = first_or_create_test! workflow_inst,
                'LL-MER-VEN-AGR-APR',
                OpenChain::WorkflowTester::MultiStateWorkflowTest,
                'Approve final attached vendor agreement & COI',
                merch_managers,
                {'state_options'=>['Approve','Reject']},
                nil,
                view_path(vendor)
            end
            vendor_agreement_approved = merch_vend_agree_approve.test! && merch_vend_agree_approve.multi_state_workflow_task.state == 'Approve'
            supplier_ref_acknowledged = sup_ref_ack.test! && sup_ref_ack.multi_state_workflow_task.state=='Acknowledge'
            if vendor_agreement_approved && supplier_ref_acknowledged #&& all the other tasks above, except triage survey which will be a dependency later
              #Placeholder for all vendor setup fields including multiple addresses
              vendor_sap_form = first_or_create_test! workflow_inst,
                'LL-VEN-SETUP',
                OpenChain::WorkflowTester::MultiStateWorkflowTest,
                'Finish sap fields',
                vendor_create,
                {'state_options'=>['Placeholder']},
                due_in_days(7),
                view_path(vendor)
              if vendor_sap_form.test!
                vendor_sap_form_internal_signoff = first_or_create_test! workflow_inst,
                  'LL-SAP-INT-ACK',
                  OpenChain::WorkflowTester::MultiStateWorkflowTest,
                  'Approve sap fields (internal)',
                  merch_managers,
                  {'state_options'=>['Approve','Reject']},
                  nil,
                  view_path(vendor)
                vendor_sap_form_vendor_signoff = first_or_create_test! workflow_inst,
                  'LL-SAP-VEN-ACK',
                  OpenChain::WorkflowTester::MultiStateWorkflowTest,
                  'Approve sap fields (external)',
                  vendor_employees,
                  {'state_options'=>['Approve','Reject']},
                  nil,
                  view_path(vendor)
                if vendor_sap_form_vendor_signoff.test! && vendor_sap_form_internal_signoff.test!
                  # if // Ask QA if sample testing is needed
                    # Attachment on QA sample testing then MultiStateWorkflow on QA sample testing complete
                  # end // Ask QA if sample testing is needed

                  # if // Lisa's triage survey is complete && QA sample testing complete or not needed
                    # initiate lisa's full audit
                    # if // lisa's full audit passes
                      # push form to SAP team
                      # require SAP number to be added to vendor
                      # if // SAP number added
                        # push DHL New vendor setup form to logistics
                      # end // SAP number added
                    # end lisa's full audit passes
                  # end // Lisa's triage surey is complete
                end
              end
            end
          end
        end
      end
    end
    return nil
  end

  private 
  def self.due_in_days increment
    Time.use_zone('Eastern Time (US & Canada)') {return increment.days.from_now.beginning_of_day}
  end

  def self.view_path base_object
    "/vendors/#{base_object.id}"
  end
end; end; end; end;