module ProjectsHelper
  def render_project p
    r = p.as_json(methods:[:red_messages])
    r['project'][:project_updates] = p.project_updates.order('updated_at DESC').collect {|pu| project_update_hash pu}
    r['project'][:project_deliverables] = p.project_deliverables.collect {|pd| project_deliverable_hash pd}
    render json: r
  end

  def project_update_hash pu
    c_by_name = (pu.created_by.blank? ? nil : pu.created_by.full_name)
    r = {id:pu.id, project_id:pu.project_id, updated_at:pu.updated_at, created_by_id:pu.created_by_id, created_by_name:c_by_name, body:pu.body}
  end

  def project_deliverable_hash pd
    assigned_name = pd.assigned_to.blank? ? nil : pd.assigned_to.full_name
    r = {id:pd.id, 
      project_id:pd.project_id, updated_at:pd.updated_at, 
      assigned_to_id:pd.assigned_to_id, assigned_to_name:assigned_name, 
      description:pd.description, due_date: pd.due_date,
      end_date:pd.end_date, estimated_hours: pd.estimated_hours,
      start_date: pd.start_date, complete: pd.complete
    }
  end

  def sanitize_project_params p
    r = {}
    [:name,:due,:objective].each {|k| r[k] = p[k]}
    r
  end

  def sanitize_project_update_params p
    {body:p[:body]}
  end
  def sanitize_project_deliverable_params p
    r = {}
    [:description, :due_date, :end_date, :estimated_hours, :start_date, :assigned_to_id, :complete].each do |k|
      r[k] = p[k]
    end
    r
  end
end
