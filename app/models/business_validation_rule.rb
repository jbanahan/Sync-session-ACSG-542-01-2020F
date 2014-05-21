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
                ValidationRuleEntryInvoiceFieldFormat: "Entry Invoice Field Format"}

  def self.subclasses_array
    SUBCLASSES.keys.collect! {|key| [SUBCLASSES[key], key.to_s]}
  end

  def rule_attributes
    self.rule_attributes_json.blank? ? nil : JSON.parse(self.rule_attributes_json)
  end

  # override to allow your business rule to skip objects
  def should_skip? obj
    self.search_criterions.each do |sc|
      sc_mf = sc.model_field
      sc_cm = sc_mf.core_module
      raise "Invalid object expected #{sc_cm.klass.name} got #{obj.class.name}" unless sc_cm == CoreModule.find_by_object(obj)
      return true unless sc.test? obj
    end
    false
  end
end
