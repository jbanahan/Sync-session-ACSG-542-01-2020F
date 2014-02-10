module ValidationResultsHelper
  def validation_state_to_bootstrap state
    panel_state = 'default'
    case state
    when 'Pass'
      panel_state = 'success'
    when 'Review'
      panel_state = 'warning'
    when 'Fail'
      panel_state = 'danger'
    end
    panel_state
  end
  def business_validation_rule_result_json rr
    return {
      id:rr.id,
      state:rr.state,
      rule:{name:rr.business_validation_rule.name,description:rr.business_validation_rule.description},
      note:rr.note,
      overridden_by:(rr.overridden_by ? {full_name:rr.overridden_by.full_name} : nil),
      overridden_at:rr.overridden_at
    }
  end
end
