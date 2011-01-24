class StatusRulesController < ApplicationController
  # GET /status_rules
  # GET /status_rules.xml
  SEARCH_PARAMS = {
    'name' => {:field => 'name', :label => 'Name'},
    'm_type' => {:field => 'module_type', :label => 'Module'},
    't_rank' => {:field => 'test_rank', :label => 'Test Rank'},
  }
  def index
    action_secure(current_user.edit_status_rules?, nil, {:verb => "work with", :lock_check => false, :module_name=>"status rule"}) {
      s = build_search(SEARCH_PARAMS,'m_type','m_type')
      respond_to do |format|
        format.html {
                @status_rules = s.paginate(:per_page => 20, :page => params[:page])
                render :layout => 'one_col'
            }
        format.xml  { render :xml => s }
      end
    }
  end

  # GET /status_rules/1
  # GET /status_rules/1.xml
  def show
    @status_rule = StatusRule.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @status_rule }
    end
  end

  # GET /status_rules/new
  # GET /status_rules/new.xml
  def new
    @status_rule = StatusRule.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @status_rule }
    end
  end

  # GET /status_rules/1/edit
  def edit
    @status_rule = StatusRule.find(params[:id])
  end

  # POST /status_rules
  # POST /status_rules.xml
  def create
    @status_rule = StatusRule.new(params[:status_rule])

    respond_to do |format|
      if @status_rule.save
        format.html { redirect_to(@status_rule, :notice => 'Status rule was successfully created.') }
        format.xml  { render :xml => @status_rule, :status => :created, :location => @status_rule }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @status_rule.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /status_rules/1
  # PUT /status_rules/1.xml
  def update
    @status_rule = StatusRule.find(params[:id])

    respond_to do |format|
      if @status_rule.update_attributes(params[:status_rule])
        format.html { redirect_to(@status_rule, :notice => 'Status rule was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @status_rule.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /status_rules/1
  # DELETE /status_rules/1.xml
  def destroy
    @status_rule = StatusRule.find(params[:id])
    @status_rule.destroy

    respond_to do |format|
      format.html { redirect_to(status_rules_url) }
      format.xml  { head :ok }
    end
  end
  
  private
  def secure
    if current_user.company.master?
      return StatusRule
    else
      return StatusRule.where("1=0")
    end
  end
end
