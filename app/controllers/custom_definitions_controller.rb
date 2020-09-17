class CustomDefinitionsController < ApplicationController
  # GET /custom_definitions
  # GET /custom_definitions.xml
  SEARCH_PARAMS = {
    'label' => {field: 'label', label: 'Label'},
    'm_type' => {field: 'module_type', label: 'Module'},
    'd_type' => {field: 'data_type', label: 'Data Type'},
    's_rank' => {field: 'rank', label: 'Sort Rank'}
  }.freeze

  def set_page_title
    @page_title = 'Tools'
  end

  def index
    s = build_search(SEARCH_PARAMS, 'label', 'm_type', 'a')

    respond_to do |format|
      format.html do
        @custom_definitions = s.paginate(per_page: 20, page: params[:page])
        render layout: 'one_col'
      end
      format.xml  { render xml: @custom_definitions }
    end
  end

  # GET /custom_definitions/1
  # GET /custom_definitions/1.xml
  def show
    redirect_to edit_custom_definition_path(CustomDefinition.find(params[:id]))
  end

  # GET /custom_definitions/new
  # GET /custom_definitions/new.xml
  def new
    c = CustomDefinition.new
    action_secure(c.can_edit?(current_user), c, {lock_check: false, verb: "create", module_name: "custom_field"}) do
      @custom_definition = c
      respond_to do |format|
        format.html # new.html.erb
        format.xml  { render xml: @custom_definition }
      end
    end
  end

  # GET /custom_definitions/1/edit
  def edit
    c = CustomDefinition.find(params[:id])
    action_secure(c.can_edit?(current_user), c, {verb: "edit", module_name: "custom field"}) do
      @custom_definition = c
    end
  end

  # POST /custom_definitions
  # POST /custom_definitions.xml
  def create
    c = CustomDefinition.new(permitted_params_new(params))
    if c.cdef_uid.blank?
      c.cdef_uid = CustomDefinition.generate_cdef_uid(c)
    end
    action_secure(c.can_edit?(current_user), c, {verb: "create", module_name: "custom field"}) do
      @custom_definition = c
      respond_to do |format|
        if @custom_definition.save
          add_flash :notices, "Custom field was created successfully."
          format.html do
            path = (!params[:and_new].nil? && params[:and_new] == "Y") ? new_custom_definition_path : custom_definitions_path
            redirect_to path
          end
          format.xml  { render xml: @custom_definition, status: :created, location: @custom_definition }
        else
          errors_to_flash @custom_definition
          format.html { render action: "new" }
          format.xml  { render xml: @custom_definition.errors, status: :unprocessable_entity }
        end
      end
    end
  end

  # PUT /custom_definitions/1
  # PUT /custom_definitions/1.xml
  def update
    c = CustomDefinition.find(params[:id])
    action_secure(c.can_edit?(current_user), c, {verb: "edit", module_name: "custom_field", yield_in_db_lock: true}) do
      @custom_definition = c
      # Module and data type cannot be updated
      respond_to do |format|
        if @custom_definition.update(permitted_params_update(params))
          @custom_definition.update_attribute!(:cdef_uid, CustomDefinition.generate_cdef_uid(@custom_definition)) if @custom_definition.cdef_uid.blank?
          add_flash :notices, "Custom field was updated successfully."
          format.html { redirect_to custom_definitions_path }
          format.xml  { head :ok }
        else
          errors_to_flash @custom_definition
          format.html { render action: "edit" }
          format.xml  { render xml: @custom_definition.errors, status: :unprocessable_entity }
        end
      end
    end
  end

  # DELETE /custom_definitions/1
  # DELETE /custom_definitions/1.xml
  def destroy
    c = CustomDefinition.find(params[:id])
    action_secure(c.can_edit?(current_user), c, {verb: "delete", module_name: "custom_field", yield_in_db_lock: true}) do
      c.destroy
      add_flash :notices, "Custom field was deleted."
      respond_to do |format|
        format.html { redirect_to(custom_definitions_url) }
        format.xml  { head :ok }
      end
    end
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

    def permitted_params_new(params)
      params.require(:custom_definition).permit(:label, :module_type, :data_type, :default_value, :rank, :tool_tip,
                                                :quick_searchable, :definition, :virtual_search_query, :virtual_value_query)
    end

    def permitted_params_update(params)
      params.require(:custom_definition).permit(:label, :default_value, :rank, :tool_tip, :quick_searchable,
                                                :definition, :virtual_search_query, :virtual_value_query)
    end
end
