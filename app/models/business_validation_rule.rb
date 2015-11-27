class BusinessValidationRule < ActiveRecord::Base
  belongs_to :business_validation_template, inverse_of: :business_validation_rules, touch: true
  attr_accessible :description, :name, :rule_attributes_json, :type, :fail_state

  has_many :search_criterions, dependent: :destroy
  has_many :business_validation_rule_results, dependent: :destroy, inverse_of: :business_validation_rule

  SUBCLASSES ||= {ValidationRuleEntryInvoiceLineFieldFormat: {label:"Entry Invoice Line Field Format"},
                ValidationRuleEntryInvoiceLineMatchesPoLine: {label:"Entry Invoice Line Matches PO Line"},
                ValidationRuleFieldFormat: {label:"Field Format"},
                ValidationRuleManual: {label:"Manual"},
                'OpenChain::CustomHandler::Polo::PoloValidationRuleEntryInvoiceLineMatchesPoLine'.to_sym=>
                  {label:"Polo Entry Invoice Line Matches PO Line", 
                    enabled_lambda: lambda {MasterSetup.get.system_code=='www-vfitrack-net'}},
                ValidationRuleEntryInvoiceLineTariffFieldFormat: {label:"Entry Invoice Tariff Field Format"},
                ValidationRuleEntryInvoiceFieldFormat: {label:"Entry Invoice Field Format"},
                ValidationRuleEntryHtsMatchesPo: {label:"Entry Invoice Line HTS Matches PO HTS"},
                ValidationRuleAnyEntryInvoiceLineHasFieldFormat: {label:"At Least One Entry Invoice Line Matches Field Format"},
                ValidationRuleAttachmentTypes: {label:"Has Attachment Types"},
                ValidationRuleCanadaGpt: {label:"Entry Tariff lines utilize Canadian GPT rates."},
                ValidationRuleEntryTariffMatchesProduct: {label:"Entry Tariff Numbers Match Parts Database"},
                ValidationRuleOrderLineProductFieldFormat: {label:"Order Line's Product Field Format"},
                ValidationRuleOrderVendorFieldFormat: {label:"Orders Vendor's Field Format"},
                ValidationRuleEntryDutyFree: {label: "Entry Invoice Tariff SPI Indicates Duty Free"},
                'OpenChain::CustomHandler::LumberLiquidators::LumberValidationRuleOrderCascadingRisk'.to_sym=>
                  {
                    label: 'Lumber PO Cascading Risk',
                    enabled_lambda: lambda {MasterSetup.get.system_code=='ll'}
                  },
                'OpenChain::CustomHandler::LumberLiquidators::LumberValidationRuleOrderVendorVariant'.to_sym=>
                  {
                    label: 'Lumber PO Vendor Variant Assignment',
                    enabled_lambda: lambda {MasterSetup.get.system_code=='ll'}
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
end

# need require statements at end because they depend on the class existing
require 'open_chain/custom_handler/lumber_liquidators/lumber_validation_rule_order_cascading_risk'
require 'open_chain/custom_handler/polo/polo_validation_rule_entry_invoice_line_matches_po_line'