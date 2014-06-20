module Api; module V1; class CompaniesController < Api::V1::ApiController
  def index
    r = {}
    if params[:roles].blank?
      ary = query_base.all
      ary << current_user.company unless ary.include? current_user.company
      r['companies'] = companies_as_json!(ary)
    else
      requested_roles = params[:roles].split(',')
      ['master','vendor','customer','importer','broker','carrier'].each { |role|
        add_role_if_requested(requested_roles,r,role)
      }
    end
    render json: r
  end

  private
  def query_base
    (current_user.company.master? ? Company : current_user.company.linked_companies).where("length(system_code) > 0")
  end
  def companies_as_json! c_list
    c_list.sort_by! {|c| c.name}
    c_list.as_json(root:false,only:[:id,:name,:master,:vendor,:customer,:importer,:broker,:system_code])
  end

  def add_role_if_requested requested_roles, return_hash, role
    if requested_roles.include? role
      return_hash[role.pluralize] = companies_as_json!(role_array(role))
    end
  end
  def role_array role_string
    sym = role_string.to_sym
    r = query_base.where(sym=>true).to_a
    r << current_user.company if current_user.company.read_attribute(sym) && !r.include?(current_user.company)
    r
  end
end; end; end