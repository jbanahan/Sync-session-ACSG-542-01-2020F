class ValidationRuleOrderVendorFieldFormat < BusinessValidationRule
  include ValidatesFieldFormat

  def run_validation ord
    vend = ord.vendor
    if vend.nil?
      return "Vendor must be set."
    end
    validate_field_format(vend) do |mf, val, regex|
      "All #{mf.label} value does not match '#{regex}' format for Vendor #{vend.name}."
    end
  end
end