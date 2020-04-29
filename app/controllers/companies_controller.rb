require 'open_chain/business_rule_validation_results_support'
require 'open_chain/custom_handler/vandegrift/kewill_product_generator'

class CompaniesController < ApplicationController
  def set_page_title
    @page_title = 'Tools'
  end
  include OpenChain::BusinessRuleValidationResultsSupport

  before_filter :translate_booking_types, only: [:create, :update]
  # GET /companies
  # GET /companies.xml
  SEARCH_PARAMS = {
    'c_name' => {:field => 'name', :label=> 'Name'},
    'c_sys_code' => {:field => 'system_code', :label=>'System Code'},
    'v_bool' => {:field => 'vendor', :label => 'Is A Vendor', :datatype => :boolean},
    'car_bool' => {:field => 'carrier', :label => 'Is A Carrier', :datatype => :boolean},
    'cus_bool' => {:field => 'customer', :label => 'Is A Customer', :datatype => :boolean},
    'imp_bool' => {:field => 'importer', :label => 'Is An Importer', :datatype => :boolean},
    'l_bool' => {:field => 'locked', :label => 'Is Locked', :datatype => :boolean},
    'c_identifier' => {field: "(SELECT code FROM system_identifiers WHERE company_id = companies.id ORDER BY created_at LIMIT 1)", label: "Company Identifier"},
    'c_identifier_type' => {field: "(SELECT system FROM system_identifiers WHERE company_id = companies.id ORDER BY created_at LIMIT 1)", label: "Company Identifier Type"}
  }

  def root_class
    Company
  end

  def index
    sp = SEARCH_PARAMS
    set_includes
    if @include_alliance
      sp = sp.clone
      sp['a_cust'] = {:field=>"(SELECT code FROM system_identifiers WHERE system = 'Customs Management' AND company_id = companies.id)", :label=>"Kewill Customer Number"}
    end
    if @include_fenix
      sp = sp.clone
      sp['a_cust_f'] = {:field=>"(SELECT code FROM system_identifiers WHERE system = 'Fenix' AND company_id = companies.id)", :label=>"Fenix Customer Number"}
    end
    if @include_cargowise
      sp = sp.clone
      sp['a_cust_c'] = {:field=>"(SELECT code FROM system_identifiers WHERE system = 'Cargowise' AND company_id = companies.id)", :label=>"Cargowise Customer Number"}
    end
    s = build_search(sp, 'c_name', 'c_name')
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
      @countries = Country.all
      set_includes
      respond_to do |format|
        format.html # show.html.erb
      end
    }
  end

  # GET /companies/new
  # GET /companies/new.xml
  def new
    @company = Company.new
    @fiscal_reference_opts = fiscal_reference_options [:ent_arrival_date, :ent_first_release, :ent_release_date,
                                                       :ent_duty_due_date, :ent_cadex_accept_date]
    action_secure(current_user.company.master, @company, {:verb => "create ", :module_name=>"company"}) {
      set_includes
      respond_to do |format|
        format.html # new.html.erb
      end
    }
  end

  # GET /companies/1/edit
  def edit
     @company = Company.find(params[:id])
     @fiscal_reference_opts = fiscal_reference_options [:ent_arrival_date, :ent_first_release, :ent_release_date,
                                                        :ent_duty_due_date, :ent_cadex_accept_date]
     action_secure(current_user.company.master, @company, {:verb => "edit", :module_name=>"company"}) {
       set_includes
     }
  end

  # POST /companies
  # POST /companies.xml
  def create
    action_secure(current_user.company.master, @company, {:verb => "create", :lock_check => false, :module_name=>"company"}) {
      set_includes
      @company = Company.create(name:params[:company][:cmp_name])
      if @company.errors.empty? && @company.update_model_field_attributes(params[:company]) && update_identifiers(@company, params[:company])
        @company.create_snapshot(current_user)
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
      Lock.db_lock(@company) do
        old_fiscal_ref = @company.fiscal_reference
        if @company.update_model_field_attributes(params[:company]) && update_identifiers(@company, params[:company])
          @company.create_snapshot(current_user)
          add_flash :notices, "Company was updated successfully."
          add_flash :notices, "FISCAL REFERENCE UPDATED. ENTRIES MUST BE RELOADED!" if @company.fiscal_reference.presence != old_fiscal_ref.presence
        else
          errors_to_flash @company
        end
        redirect_to redirect_location(@company)
      end
    }
  end


  def validation_results
    generic_validation_results(Company.find params[:id])
  end

  def shipping_address_list
    c = Company.find(params[:id])
    action_secure(c.can_view?(current_user), c, {:lock_check => false, :module_name => "company", :verb => "view addresses for"}) {
      respond_to do |format|
        format.json { render :json => c.addresses.where(:shipping => true).to_json(:only => [:id, :name])}
      end
    }
  end

  def show_children
    if !current_user.admin? || !current_user.company.master?
      error_redirect "You do not have permission to work with linked companies."
      return
    end
    @company = Company.find params[:id]
    @unlinked_company_options = Company.options_for_companies_with_system_identifier(['Customs Management', 'Fenix', 'Cargowise'], in_relation: @company.unlinked_companies(select: "distinct companies.id"), join_type: :outer)
    @linked_company_options = Company.options_for_companies_with_system_identifier(['Customs Management', 'Fenix', 'Cargowise'], in_relation: @company.linked_companies, join_type: :outer)
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

  # send the generic fixed position file to Alliance for this importer
  def push_alliance_products
    raise ActionController::RoutingError.new('Not Found') unless MasterSetup.get.custom_feature?("Kewill Product Push")

    c = Company.find params[:id]
    admin_secure do
      if c.kewill_customer_number.blank?
        add_flash :errors, "Cannot push file because company doesn't have an alliance customer number."
      else
        OpenChain::CustomHandler::Vandegrift::KewillProductGenerator.delay.sync(c.kewill_customer_number)
        c.update_attributes! :last_alliance_product_push_at => Time.zone.now
        add_flash :notices, "Product file has been queued to be sent to Kewill."
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

    def translate_booking_types
      if params[:company][:cmp_enabled_booking_types].respond_to?(:join)
        params[:company][:cmp_enabled_booking_types] = params[:company][:cmp_enabled_booking_types].join("\n ")
      end
    end

    def fiscal_reference_options uids
      opts = [[nil, ""]]
      uids.each do |uid|
        mf = ModelField.find_by_uid uid
        next unless mf
        opts << [mf.label, uid]
      end
      opts
    end

    def set_includes
      @include_alliance = MasterSetup.get.custom_feature?('alliance')
      @include_fenix = MasterSetup.get.custom_feature?('fenix')
      @include_cargowise = MasterSetup.get.custom_feature?("Maersk Cargowise Feeds")
    end

    def update_identifiers company, params
      company.set_system_identifier("Customs Management", params[:kewill_customer_number]) if params[:kewill_customer_number]
      company.set_system_identifier("Fenix", params[:fenix_customer_number]) if params[:fenix_customer_number]
      company.set_system_identifier("Cargowise", params[:cargowise_customer_number]) if params[:cargowise_customer_number]
      true
    end
end
