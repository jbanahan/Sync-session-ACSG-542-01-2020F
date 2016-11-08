class BusinessValidationRule < ActiveRecord::Base
  belongs_to :business_validation_template, inverse_of: :business_validation_rules, touch: true
  belongs_to :group
  attr_accessible :description, :name, :rule_attributes_json, :type, :group_id, :fail_state, :delete_pending

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
                    enabled_lambda: lambda {MasterSetup.get.system_code=='www-vfitrack-net'}},
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
                ValidationRuleEntryInvoiceChargeCode: {label: "Entry Broker Invoice Charge Codes"},
                'OpenChain::CustomHandler::Ascena::ValidationRuleAscenaInvoiceAudit'.to_sym=>
                  {
                    label: "Ascena Entry Invoice Audit",
                    enabled_lambda: lambda {MasterSetup.get.system_code=='www-vfitrack-net'}
                  },
                'OpenChain::CustomHandler::LumberLiquidators::LumberValidationRuleOrderVendorVariant'.to_sym=>
                  {
                    label: 'Lumber PO Vendor Variant Assignment',
                    enabled_lambda: lambda {MasterSetup.get.system_code=='ll'}
                  },
                'OpenChain::CustomHandler::LumberLiquidators::LumberValidationRuleEntryInvoicePartMatchesOrder'.to_sym=>
                  {
                    label: 'Lumber Entry Invoice Part Matches Order',
                    enabled_lambda: lambda {MasterSetup.get.system_code=='www-vfitrack-net'}
                  },
                'OpenChain::CustomHandler::Pepsi::QuakerValidationRulePoNumberUnique'.to_sym=>
                  {
                    label: 'Quaker Entry PO Number Unique',
                    enabled_lambda: lambda {MasterSetup.get.system_code=='www-vfitrack-net'}  
                  },
                'OpenChain::CustomHandler::Hm::ValidationRuleHmInvoiceLineFieldFormat'.to_sym=>
                  {
                    label: 'H&M Invoice Line Field Format',
                    enabled_lambda: lambda {MasterSetup.get.system_code=='www-vfitrack-net'}  
                  }
              }

  def self.subclasses_array
    r = SUBCLASSES.collect {|k,v|
      v[:enabled_lambda] && !v[:enabled_lambda].call ? nil : [v[:label], k.to_s]
    }
    r.compact!
    r.sort! {|pair1,pair2| pair1[0] <=> pair2[0]}
  end

  def rule_attributes
    @parsed_rule_attributes ||= self.rule_attributes_json.blank? ? {} : JSON.parse(self.rule_attributes_json)
    @parsed_rule_attributes
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
require_dependency 'open_chain/custom_handler/hm/validation_rule_hm_invoice_line_field_format'