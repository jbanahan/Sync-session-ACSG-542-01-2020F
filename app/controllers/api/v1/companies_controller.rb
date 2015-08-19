module Api; module V1; class CompaniesController < Api::V1::ApiCoreModuleControllerBase
  def index
    r = {}
    if params[:roles].blank?
      ary = query_base(params[:linked_with]).all
      ary << current_user.company unless ary.include? current_user.company
      r['companies'] = companies_as_json!(ary)
    else
      requested_roles = params[:roles].split(',')
      ['master','vendor','customer','importer','broker','carrier'].each { |role|
        add_role_if_requested(requested_roles,r,role, params[:linked_with])
      }
    end
    render json: r
  end

  def core_module
    CoreModule::COMPANY
  end

  private
  def query_base linked_with = nil
    r = (current_user.company.master? ? Company : current_user.company.linked_companies).where("length(trim(system_code)) > 0")
    if linked_with.to_i > 0
      r = r.joins("INNER JOIN linked_companies linked ON linked.parent_id = #{linked_with} AND linked.child_id = companies.id")
    end
    r
  end

  def companies_as_json! c_list
    c_list.sort_by! {|c| c.name}
    c_list.as_json(root:false,only:[:id,:name,:master,:vendor,:customer,:importer,:broker,:system_code])
  end

  def add_role_if_requested requested_roles, return_hash, role, linked_with = nil
    if requested_roles.include? role
      return_hash[role.pluralize] = companies_as_json!(role_array(role, linked_with))
    end
  end

  def role_array role_string, linked_with = nil
    sym = role_string.to_sym
    r = query_base(linked_with).where(sym=>true).to_a
    r << current_user.company if current_user.company.read_attribute(sym) && !r.include?(current_user.company) && !current_user.company.system_code.blank?
    r
  end
end; end; end
