class ValidationRuleEntryReleased < BusinessValidationRule
  def run_validation entry
    timezone = rule_attributes['timezone'] || "America/New_York"

    hold_date_field = ModelField.find_by_uid(rule_attributes['hold_date'])
    raise "Invalid Hold model field value of #{rule_attributes['hold_date']} used" if hold_date_field.blank?

    release_date_field = ModelField.find_by_uid(rule_attributes['release_date'])
    raise "Invalid Release model field value of #{rule_attributes['release_date']} used" if release_date_field.blank?

    hold_date = hold_date_field.process_export(entry, nil, true) if hold_date_field
    release_date = release_date_field.process_export(entry, nil, true) if release_date_field

    if hold_date.blank?
      nil
    elsif hold_date.present? && release_date.blank?
      "Entry #{entry.entry_number} is on hold. #{hold_date_field.base_label} is #{hold_date.in_time_zone(timezone).strftime("%Y-%m-%d %H:%M %Z")}"
    elsif hold_date.present? && release_date.present?
      nil
    else
      nil
    end
  end
end