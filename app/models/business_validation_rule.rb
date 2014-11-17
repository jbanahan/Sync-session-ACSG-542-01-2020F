class BusinessValidationRule < ActiveRecord::Base
  belongs_to :business_validation_template, inverse_of: :business_validation_rules, touch: true
  attr_accessible :description, :name, :rule_attributes_json, :type, :fail_state

  has_many :search_criterions, dependent: :destroy
  has_many :business_validation_rule_results, dependent: :destroy, inverse_of: :business_validation_rule

  SUBCLASSES ||= {ValidationRuleEntryInvoiceLineFieldFormat: "Entry Invoice Line Field Format",
                ValidationRuleEntryInvoiceLineMatchesPoLine: "Entry Invoice Line Matches PO Line",
                ValidationRuleFieldFormat: "Field Format",
                ValidationRuleManual: "Manual",
                PoloValidationRuleEntryInvoiceLineMatchesPoLine: "(Polo) Entry Invoice Line Matches PO Line",
                ValidationRuleEntryInvoiceLineTariffFieldFormat: "Entry Invoice Tariff Field Format",
                ValidationRuleEntryInvoiceFieldFormat: "Entry Invoice Field Format",
                ValidationRuleEntryHtsMatchesPo: "Entry Invoice Line HTS Matches PO HTS",
                ValidationRuleAnyEntryInvoiceLineHasFieldFormat: "At Least One Entry Invoice Line Matches Field Format",
                ValidationRuleAttachmentTypes: "Has Attachment Types",
                ValidationRuleCanadaGpt: "Entry Tariff lines utilize Canadian GPT rates."
              }

  def self.subclasses_array
    SUBCLASSES.keys.collect! {|key| [SUBCLASSES[key], key.to_s]}
  end

  def rule_attributes
    self.rule_attributes_json.blank? ? {} : JSON.parse(self.rule_attributes_json)
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
end
