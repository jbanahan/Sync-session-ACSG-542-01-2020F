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
end
