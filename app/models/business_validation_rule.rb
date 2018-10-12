# == Schema Information
#
# Table name: business_validation_rules
#
#  business_validation_template_id :integer
#  created_at                      :datetime         not null
#  delete_pending                  :boolean
#  description                     :string(255)
#  disabled                        :boolean
#  fail_state                      :string(255)
#  group_id                        :integer
#  id                              :integer          not null, primary key
#  mailing_list_id                 :integer
#  message_pass                    :string(255)
#  message_review_fail             :string(255)
#  message_skipped                 :string(255)
#  name                            :string(255)
#  notification_recipients         :text
#  notification_type               :string(255)
#  rule_attributes_json            :text
#  subject_pass                    :string(255)
#  subject_review_fail             :string(255)
#  subject_skipped                 :string(255)
#  suppress_pass_notice            :boolean
#  suppress_review_fail_notice     :boolean
#  suppress_skipped_notice         :boolean
#  type                            :string(255)
#  updated_at                      :datetime         not null
#
# Indexes
#
#  template_id  (business_validation_template_id)
#

class BusinessValidationRule < ActiveRecord::Base
  belongs_to :business_validation_template, inverse_of: :business_validation_rules, touch: true
  belongs_to :group
  belongs_to :mailing_list
  attr_accessible :description, :name, :disabled, :rule_attributes_json, :type, :group_id, :fail_state, :delete_pending, :notification_type, 
                  :notification_recipients, :suppress_pass_notice, :suppress_review_fail_notice, :suppress_skipped_notice, :subject_pass, :subject_review_fail, :subject_skipped,
                  :message_pass, :message_review_fail, :message_skipped, :mailing_list_id

  has_many :search_criterions, dependent: :destroy
  # dependent destroy is NOT added here because of the potential for hundreds of thousands of dependent records (it absolutely happens)
  # so we must manually delete the results.  The after_destroy callback below handles this.
  has_many :business_validation_rule_results, inverse_of: :business_validation_rule

  after_destroy { |rule| destroy_rule_dependents rule }

  SUBCLASSES ||= {ValidationRuleEntryInvoiceLineFieldFormat: {label:"Entry Invoice Line Field Format"},
                ValidationRuleEntryInvoiceLineMatchesPoLine: {label:"Entry Invoice Line Matches PO Line"},
                ValidationRuleFieldFormat: {label:"Field Format"},
                ValidationRuleManual: {label:"Manual"},
                'OpenChain::CustomHandler::Polo::PoloValidationRuleEntryInvoiceLineMatchesPoLine'.to_sym=>
                  {label:"Polo Entry Invoice Line Matches PO Line", 
                    enabled_lambda: lambda { MasterSetup.get.custom_feature? "Vandegrift Business Rules" }},
                ValidationRuleEntryInvoiceLineTariffFieldFormat: {label:"Entry Invoice Tariff Field Format"},
                ValidationRuleEntryInvoiceFieldFormat: {label:"Entry Invoice Field Format"},
                ValidationRuleOrderLineFieldFormat: {label: "Order Line Field Format"},
                ValidationRuleEntryHtsMatchesPo: {label:"Entry Invoice Line HTS Matches PO HTS"},
                ValidationRuleAnyEntryInvoiceLineHasFieldFormat: {label:"At Least One Entry Invoice Line Matches Field Format"},
                ValidationRuleEntryInvoiceCooMatchesSpi: {label:"Entry Invoice Line Country of Origin Matches Primary SPI"},
                ValidationRuleAttachmentTypes: {label:"Has Attachment Types"},
                ValidationRuleCanadaGpt: {label:"Entry Tariff lines utilize Canadian GPT rates."},
                ValidationRuleEntryTariffMatchesProduct: {label:"Entry Tariff Numbers Match Parts Database"},
                ValidationRuleOrderLineProductFieldFormat: {label:"Order Line's Product Field Format"},
                ValidationRuleOrderVendorFieldFormat: {label:"Orders Vendor's Field Format"},
                ValidationRuleEntryDutyFree: {label: "Entry Invoice Tariff SPI Indicates Duty Free"},
                ValidationRuleEntryInvoiceValueMatchesDaPercent: {label: "Entry Total Matches Invoice Deduction Additions"},
                ValidationRuleProductClassificationFieldFormat: {label:"Product Classification Field Format"},
                ValidationRuleBrokerInvoiceFieldFormat: {label: 'Broker Invoice Field Format'},
                ValidationRuleBrokerInvoiceLineFieldFormat: {label: 'Broker Invoice Line Field Format'},
                ValidationRuleEntryInvoiceChargeCode: {label: "Entry Broker Invoice Charge Codes"},
                #DEPRECATED - doesn't appear in menu
                ValidationRuleFieldComparison: {label: "Field Comparison", enabled_lambda: lambda { nil } },
                'OpenChain::CustomHandler::Ascena::ValidationRuleAscenaInvoiceAudit'.to_sym=>
                  {
                    label: "Ascena Entry Invoice Audit",
                    enabled_lambda: lambda { MasterSetup.get.custom_feature? "Vandegrift Business Rules" }
                  },
                'OpenChain::CustomHandler::LumberLiquidators::LumberValidationRuleOrderVendorVariant'.to_sym=>
                  {
                    label: 'Lumber PO Vendor Variant Assignment',
                    enabled_lambda: lambda { MasterSetup.get.custom_feature? "Lumber Business Rules" }
                  },
                'OpenChain::CustomHandler::LumberLiquidators::LumberValidationRuleEntryInvoicePartMatchesOrder'.to_sym=>
                  {
                    label: 'Lumber Entry Invoice Part Matches Order',
                    enabled_lambda: lambda { MasterSetup.get.custom_feature? "Vandegrift Business Rules" }
                  },
                'OpenChain::CustomHandler::Pepsi::QuakerValidationRulePoNumberUnique'.to_sym=>
                  {
                    label: 'Quaker Entry PO Number Unique',
                    enabled_lambda: lambda { MasterSetup.get.custom_feature? "Vandegrift Business Rules" }
                  },
                'OpenChain::CustomHandler::Hm::ValidationRuleHmInvoiceLineFieldFormat'.to_sym=>
                  {
                    label: 'H&M Invoice Line Field Format',
                    enabled_lambda: lambda { MasterSetup.get.custom_feature? "Vandegrift Business Rules" }
                  },
                'OpenChain::CustomHandler::Ascena::ValidationRuleAscenaFirstSale'.to_sym=>
                {
                  label: "Ascena First Sale Validation",
                  enabled_lambda: lambda { MasterSetup.get.custom_feature? "Vandegrift Business Rules" }
                },
                ValidationRuleEntryInvoiceLineMatchesPo: {label:"Entry Invoice Line Matches PO"},
                "OpenChain::CustomHandler::Vandegrift::KewillEntryStatementValidationRule".to_sym => {label: "US Customs Statement Validations", enabled_lamda: lambda { MasterSetup.get.custom_feature? "Vandegrift Business Rules"} },
                ValidationRuleEntryDoesNotSharePos: {label:"Entry PO Numbers Not Shared"},
                ValidationRuleEntryReleased: {label: "Entry Not On Hold"},
                'OpenChain::CustomHandler::AnnInc::AnnMpTypeAllDocsValidationRule'.to_sym =>
                  {
                    label: 'Ann Vendor MP Type All Docs',
                    enabled_lambda: lambda {MasterSetup.get.system_code=='ann'}
                  },
                'OpenChain::CustomHandler::AnnInc::AnnMpTypeUponRequestValidationRule'.to_sym =>
                  {
                    label: 'Ann Vendor MP Type Upon Request',
                    enabled_lambda: lambda {MasterSetup.get.system_code=='ann'}
                  },
                'OpenChain::CustomHandler::AnnInc::AnnFirstSaleValidationRule'.to_sym =>
                 {
                    label: 'Ann First Sale Validations',
                    enabled_lambda: lambda {MasterSetup.get.custom_feature? "Ann"}
                 },
                 ValidationRuleEntrySpecialTariffsClaimed: {label: "Verify Claimed Special Tariffs"},
                 ValidationRuleEntrySpecialTariffsNotClaimed: {label: "Ensure Special Tariffs Are Claimed"}
              }

  def recipients_and_mailing_lists
    emails = self.notification_recipients

    if mailing_list.present?
      formatted_emails = mailing_list.split_emails.join(', ')
      if emails.present?
        emails << ", #{formatted_emails}"
      else
       emails = formatted_emails
      end
    end
    emails
  end

  def self.subclasses_array
    r = SUBCLASSES.collect {|k,v|
      v[:enabled_lambda] && !v[:enabled_lambda].call ? nil : [v[:label], k.to_s]
    }
    r.compact!
    r.sort! {|pair1,pair2| pair1[0] <=> pair2[0]}
  end

  def active?
    !self.disabled? && !self.delete_pending && !!self.business_validation_template.try(:active?)
  end

  def rule_attributes
    @parsed_rule_attributes ||= self.rule_attributes_json.blank? ? {} : JSON.parse(self.rule_attributes_json)
    @parsed_rule_attributes
  end

  # All this method really does is return true if a rule attribute key
  # is set with a boolean or string that evaluates to a true boolean (#to_boolean)
  def has_flag? flag_key
    (rule_attributes[flag_key].presence || false).to_s.to_boolean
  end

  # override to allow your business rule to skip objects
  def should_skip? obj
    self.search_criterions.each do |sc|
      sc_mf = sc.model_field
      next if sc_mf.blank?
      
      sc_cm = sc_mf.core_module
      raise "Invalid object expected #{sc_cm.klass.name} got #{obj.class.name}" unless sc_cm == CoreModule.find_by_object(obj)
      return true unless sc.test? obj
    end
    false
  end

  # override to turn off the rule for subclasses_array
  def self.enabled?
    true
  end

  def destroy_rule_dependents validation_rule
    self.class.delay.destroy_rule_results validation_rule.id
  end

  def self.destroy_rule_results rule_id
    # There's far too many business_validation_rule_results linked to a single rule to be able to cascade and delete in a single transaction (.ie directly
    # via a destroy and a defined dependents destroy in the relation definition).
    # Destroy them in groups of 1000 in their own distinct asynchronous transactions

    # Do the "newer" ones first
    ids = BusinessValidationRuleResult.where(business_validation_rule_id: rule_id).order("id DESC").pluck :id
    ids.each_slice(1000).each do |id_group|
      # Give these a very low priority.
      BusinessValidationRuleResult.delay(priority: 100).destroy_batch id_group
    end
  end

end

# need require statements at end because they depend on the class existing
require_dependency 'open_chain/custom_handler/lumber_liquidators/lumber_validation_rule_order_vendor_variant'
require_dependency 'open_chain/custom_handler/ascena/validation_rule_ascena_invoice_audit'
require_dependency 'open_chain/custom_handler/ascena/validation_rule_ascena_first_sale'
require_dependency 'open_chain/custom_handler/hm/validation_rule_hm_invoice_line_field_format'
require_dependency 'open_chain/custom_handler/ann_inc/ann_mp_type_all_docs_validation_rule'
require_dependency 'open_chain/custom_handler/ann_inc/ann_mp_type_upon_request_validation_rule'
require_dependency 'open_chain/custom_handler/ann_inc/ann_first_sale_validation_rule'

require_dependency 'open_chain/custom_handler/vandegrift/kewill_entry_statement_validation_rule'
