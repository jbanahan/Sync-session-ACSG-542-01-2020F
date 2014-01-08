module ProjectsHelper
  def render_project p
    r = p.as_json(methods:[:red_messages])
    r['project'][:project_updates] = p.project_updates.order('updated_at DESC').collect {|pu| project_update_hash pu}
    render json: r
  end

  def project_update_hash pu
    c_by_name = (pu.created_by.blank? ? nil : pu.created_by.full_name)
    r = {id:pu.id, project_id:pu.project_id, updated_at:pu.updated_at, created_by_id:pu.created_by_id, created_by_name:c_by_name, body:pu.body}
  end

  def sanitize_project_params p
    r = {}
    [:name,:due,:objective].each {|k| r[k] = p[k]}
    r
  end
end
