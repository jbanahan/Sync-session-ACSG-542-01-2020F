class CustomDefinitionsController < ApplicationController
  # GET /custom_definitions
  # GET /custom_definitions.xml
	SEARCH_PARAMS = {
			'label' => {:field => 'label', :label=> 'Label'},
			'm_type' => {:field => 'module_type', :label => 'Module'},
			'd_type' => {:field => 'data_type', :label => 'Data Type'},
			's_rank' => {:field => 'rank', :label => 'Sort Rank'}
	}
  def index
		s =  build_search(SEARCH_PARAMS,'label','label','a')

    respond_to do |format|
      format.html {
				@custom_definitions = s.all.paginate(:per_page => 20, :page => params[:page])
        render :layout => 'one_col'
			} 
      format.xml  { render :xml => @custom_definitions }
    end
  end

  # GET /custom_definitions/1
  # GET /custom_definitions/1.xml
  def show
    c = CustomDefinition.find(params[:id])
		action_secure(c.can_view?(current_user),c,{:lock_check => false, :verb => "view", :module_name=>"custom field"}) {
			@custom_definition = c
			respond_to do |format|
				format.html # show.html.erb
				format.xml  { render :xml => @custom_definition }
			end
		}
  end

  # GET /custom_definitions/new
  # GET /custom_definitions/new.xml
  def new
    c = CustomDefinition.new
		action_secure(c.can_edit?(current_user),c,{:lock_check => false, :verb => "create", :module_name=>"custom_field"}) {
			@custom_definition = c
			respond_to do |format|
				format.html # new.html.erb
				format.xml  { render :xml => @custom_definition }
			end
		}
  end

  # GET /custom_definitions/1/edit
  def edit
    c = CustomDefinition.find(params[:id])
		action_secure(c.can_edit?(current_user),c,{:verb => "edit", :module_name=>"custom field"}) {
			@custom_definition = c
		}
  end

  # POST /custom_definitions
  # POST /custom_definitions.xml
  def create
    c = CustomDefinition.new(params[:custom_definition])
		action_secure(c.can_edit?(current_user),c,{:verb => "create", :module_name=>"custom field"}) {
			@custom_definition = c
			respond_to do |format|
				if @custom_definition.save
					add_flash :notices, "Custom field was created successfully."
					format.html { redirect_to(@custom_definition, :notice => 'Custom definition was successfully created.') }
					format.xml  { render :xml => @custom_definition, :status => :created, :location => @custom_definition }
				else
					errors_to_flash @custom_definition
					format.html { render :action => "new" }
					format.xml  { render :xml => @custom_definition.errors, :status => :unprocessable_entity }
				end
			end
		}
  end

  # PUT /custom_definitions/1
  # PUT /custom_definitions/1.xml
  def update
    c = CustomDefinition.find(params[:id])
		action_secure(c.can_edit?(current_user),c,{:verb=>"edit", :module_name=>"custom_field"}) {
			@custom_definition = c
			respond_to do |format|
				if @custom_definition.update_attributes(params[:custom_definition])
					add_flash :notices, "Custom field was updated successfully."
					format.html { redirect_to(@custom_definition, :notice => 'Custom definition was successfully updated.') }
					format.xml  { head :ok }
				else
					errors_to_flash @custom_definition
					format.html { render :action => "edit" }
					format.xml  { render :xml => @custom_definition.errors, :status => :unprocessable_entity }
				end
			end
		}
  end

  # DELETE /custom_definitions/1
  # DELETE /custom_definitions/1.xml
  def destroy
    c = CustomDefinition.find(params[:id])
		action_secure(c.can_edit?(current_user),c,{:verb=>"delete", :module_name=>"custom field"}) {
			c.destroy
			add_flash :notices, "Custom field was deleted."
			respond_to do |format|
				format.html { redirect_to(custom_definitions_url) }
				format.xml  { head :ok }
			end
		}
  end
	
	private    
    def secure
			r = CustomDefinition.where("1=0")
			if current_user.company.master
				r = CustomDefinition
			else
				add_flash :errors, "You do not have permission to search for custom fields."
				return CustomDefinition.where("1=0")
			end
			r
    end
end
