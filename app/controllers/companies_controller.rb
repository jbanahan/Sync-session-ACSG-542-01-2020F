class CompaniesController < ApplicationController
  # GET /companies
  # GET /companies.xml
  SEARCH_PARAMS = {
    'c_name' => {:field => 'name', :label=> 'Name'},
    'v_bool' => {:field => 'vendor', :label => 'Is A Vendor'},
    'car_bool' => {:field => 'carrier', :label => 'Is A Carrier'},
    'cus_bool' => {:field => 'customer', :label => 'Is A Customer'},
    'imp_bool' => {:field => 'importer', :label => 'Is An Importer'},
    'l_bool' => {:field => 'locked', :label => 'Is Locked'}
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
        format.xml  { render :xml => (@orders=s.all) }
    end
  end

  # GET /companies/1
  # GET /companies/1.xml
  def show
    @company = Company.find(params[:id])
    action_secure(@company.can_view?(current_user), @company, {:verb => "view", :lock_check => false, :module_name=>"company"}) {
      @countries = Country.all  
      respond_to do |format|
        format.html # show.html.erb
        format.xml  { render :xml => @company }
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
        format.xml  { render :xml => @company }
      end
    }
  end

  # GET /companies/1/edit
  def edit
     @company = Company.find(params[:id])
     action_secure(current_user.company.master, @company, {:verb => "edit", :module_name=>"company"}) { 
       #no extras needed
     }
  end

  # POST /companies
  # POST /companies.xml
  def create
    @company = Company.new(params[:company])
    action_secure(current_user.company.master, @company, {:verb => "create", :lock_check => false, :module_name=>"company"}) {
      respond_to do |format|
        if @company.save
          add_flash :notices, "Company created successfully."
          format.html { redirect_to(@company) }
          format.xml  { render :xml => @company, :status => :created, :location => @company }
        else
          errors_to_flash @company, :now => true
          format.html { render :action => "new" }
          format.xml  { render :xml => @company.errors, :status => :unprocessable_entity }
        end
      end
    }
  end

  # PUT /companies/1
  # PUT /companies/1.xml
  def update
    @company = Company.find(params[:id])
    unlocking = !params[:company][:locked].nil? && params[:company][:locked]=="0"
    action_secure(current_user.company.master, @company, {:lock_check => !unlocking, :module_name => "company"}) {
      respond_to do |format|
        if @company.update_attributes(params[:company])
          add_flash :notices, "Company was updated successfully."
          format.html { redirect_to(@company) }
          format.xml  { head :ok }
        else
          errors_to_flash @company, :now => true
          format.html { render :action => "edit" }
          format.xml  { render :xml => @company.errors, :status => :unprocessable_entity }
        end
      end      
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
    c.linked_company_ids = params[:selected].values
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
  private 
  def secure
    Company.find_can_view(current_user)
  end
end
