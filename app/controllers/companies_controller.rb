require 'open_chain/custom_handler/generic_alliance_product_generator'
require 'open_chain/workflow_processor'
class CompaniesController < ApplicationController
  # GET /companies
  # GET /companies.xml
  SEARCH_PARAMS = {
    'c_name' => {:field => 'name', :label=> 'Name'},
    'c_sys_code' => {:field => 'system_code', :label=>'System Code'},
    'v_bool' => {:field => 'vendor', :label => 'Is A Vendor', :datatype => :boolean},
    'car_bool' => {:field => 'carrier', :label => 'Is A Carrier', :datatype => :boolean},
    'cus_bool' => {:field => 'customer', :label => 'Is A Customer', :datatype => :boolean},
    'imp_bool' => {:field => 'importer', :label => 'Is An Importer', :datatype => :boolean},
    'l_bool' => {:field => 'locked', :label => 'Is Locked', :datatype => :boolean}
  }
  def index
    sp = SEARCH_PARAMS
    if MasterSetup.get.custom_feature? 'alliance'
      sp = sp.clone
      sp['a_cust'] = {:field=>'alliance_customer_number', :label=>"Alliance Customer Number"}
      @include_alliance = true
    end
    if MasterSetup.get.custom_feature? 'fenix'
      sp = sp.clone
      sp['a_cust_f'] = {:field=>'fenix_customer_number', :label=>"Fenix Customer Number"}
      @include_fenix = true
    end
    s = build_search(sp,'c_name','c_name')
    respond_to do |format|
        format.html {
            @companies = s.paginate(:per_page => 20, :page => params[:page])
            render :layout => 'one_col'
        }
    end
  end

  # GET /companies/1
  # GET /companies/1.xml
  def show
    @company = Company.find(params[:id])
    action_secure(@company.can_view?(current_user), @company, {:verb => "view", :lock_check => false, :module_name=>"company"}) {
      enable_workflow @company
      @countries = Country.all  
      respond_to do |format|
        format.html # show.html.erb
      end
    }
  end

  # GET /companies/new
  # GET /companies/new.xml
  def new
    @company = Company.new
    action_secure(current_user.company.master, @company, {:verb => "create ", :module_name=>"company"}) {
      respond_to do |format|
        format.html # new.html.erb
      end
    }
  end

  # GET /companies/1/edit
  def edit
     @company = Company.find(params[:id])
     action_secure(current_user.company.master, @company, {:verb => "edit", :module_name=>"company"}) { 
       enable_workflow @company
     }
  end

  # POST /companies
  # POST /companies.xml
  def create
    action_secure(current_user.company.master, @company, {:verb => "create", :lock_check => false, :module_name=>"company"}) {
      @company = Company.create(name:params[:company][:cmp_name])
      if @company.errors.empty? && @company.update_model_field_attributes(params[:company])
        OpenChain::WorkflowProcessor.async_process @company
        add_flash :notices, "Company created successfully."
      else
        errors_to_flash @company
      end
      redirect_to redirect_location(@company)
    }
  end

  # PUT /companies/1
  # PUT /companies/1.xml
  def update
    @company = Company.find(params[:id])
    unlocking = !params[:company][:locked].nil? && params[:company][:locked]=="0"
    action_secure(current_user.company.master, @company, {:lock_check => !unlocking, :module_name => "company"}) {
      if @company.update_model_field_attributes(params[:company])
        OpenChain::WorkflowProcessor.async_process @company
        add_flash :notices, "Company was updated successfully."
      else
        errors_to_flash @company
      end
      redirect_to redirect_location(@company)
    }
  end
  
  def shipping_address_list
    c = Company.find(params[:id])
    action_secure(c.can_view?(current_user),c,{:lock_check => false, :module_name => "company", :verb => "view addresses for"}) {
      respond_to do |format|
        format.json { render :json => c.addresses.where(:shipping => true).to_json(:only => [:id,:name])}
      end
    }
  end

  def show_children
    if !current_user.admin? || !current_user.company.master?
      error_redirect "You do not have permission to work with linked companies."
      return
    end
    @company = Company.find params[:id]
  end
  
  def update_children
    if !current_user.admin? || !current_user.company.master?
      error_redirect "You do not have permission to work with linked companies."
      return
    end
    c = Company.find params[:id]
    c.linked_company_ids = (params[:selected].nil? ? [] : params[:selected].values)
    add_flash :notices, "Linked companies saved successfully."
    redirect_to show_children_company_path c
  end

  def attachment_archive_enabled
    if !current_user.company.master?
      error_redirect "You do not have permission to access this page."
      return
    end
    render :json=>Company.attachment_archive_enabled.by_name.to_json(:include=>{:attachment_archive_setup=>{:methods=>:entry_attachments_available_count}})
  end

  #send the generic fixed position file to Alliance for this importer
  def push_alliance_products
    c = Company.find params[:id]
    admin_secure do
      if !MasterSetup.get.custom_feature? 'alliance'
        add_flash :errors, "Cannot push file because \"alliance\" custom feature is not enabled."
      elsif c.alliance_customer_number.blank?
        add_flash :errors, "Cannot push file because company doesn't have an alliance customer number."
      elsif c.last_alliance_product_push_at && c.last_alliance_product_push_at > 10.minutes.ago
        add_flash :errors, "Cannot push file because last push was less than 10 minutes ago."
      else
        OpenChain::CustomHandler::GenericAllianceProductGenerator.delay.sync(c.id)
        c.update_attributes :last_alliance_product_push_at => 0.seconds.ago
        add_flash :notices, "Product file has been queued to be sent to alliance."
      end
      redirect_to c
    end
  end
  private 
  def secure
    Company.find_can_view(current_user)
  end
  def redirect_location company
    params[:redirect_to].blank? ? company : params[:redirect_to]
  end
end
