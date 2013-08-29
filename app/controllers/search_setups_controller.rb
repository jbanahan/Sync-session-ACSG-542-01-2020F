class SearchSetupsController < ApplicationController
  
  def show
    search_setup = SearchSetup.for_user(current_user).find(params[:id])
    respond_to do |format|
      format.json { render :json => search_setup.to_json(:methods=>[:uploadable_error_messages],:include => {:search_columns=>{:only=>[:model_field_uid,:rank]}, 
          :sort_criterions=>{:only=>[:model_field_uid,:rank,:descending]}}) }
    end 
  end

  def attachments
    @search = SearchSetup.for_user(current_user).find(params[:id])
    @results = @search.search.has_attachment.paginate(:per_page=>50,:page => params[:page])
    render :layout=>'one_col'
  end
  
  def update
    search_setup = SearchSetup.for_user(current_user).find(params[:id])
    if search_setup.nil?
      error_redirect "Search with ID #{params[:id]} not found."
    else
      # Modify the search criterion values for date times for lt, gt, eq, ne operators
      # adding in the user's time zone.
      append_timezone_to_datetime params

      search_setup.search_columns.destroy_all if !params[:search_setup][:search_columns_attributes].blank? #clear, they will be reloaded
      search_setup.sort_criterions.destroy_all #clear, they will be reloaded
      search_setup.update_attributes(params[:search_setup])
      redirect_to Kernel.const_get(search_setup.module_type)
    end
  end
  
  def copy
    base = SearchSetup.for_user(current_user).find(params[:id])
    if base.nil?
      error_message = "Search with ID #{params[:id]} not found."
      respond_to do |format|
        format.html {
          error_redirect error_message
        }
        format.json {
          render :json=>{"error"=>error_message}, :status=>422
        }
      end
    else
      new_name = params[:new_name]
      new_name = "Copy of #{base.name}" if new_name.blank?
      # Make sure there's no report that already has this name..
      existing = SearchSetup.for_user(current_user).where(module_type: base.module_type, name: new_name).first
      if existing
        error_message = "A search with the name '#{new_name}' already exists.  Please use a different name or rename the existing report."
        respond_to do |format|
          format.html {
            add_flash :errors, error_message
            redirect_to Kernel.const_get(base.module_type)
          }
          format.json {
            render :json=>{"error"=>error_message}, :status=>422
          }
        end
      else
        copy = base.deep_copy(new_name)
        copy.touch
        respond_to do |format|
          format.html {
            add_flash :notices, "A copy of this report has been created as '" + copy.name + "'."
            redirect_to Kernel.const_get(copy.module_type)
          }
          format.json {
            render :json=>{"ok"=>"ok", "id"=>copy.id, "name"=>copy.name}
          }
        end
      end
    end
  end
  def give
    base = SearchSetup.for_user(current_user).find_by_id(params[:id])
    raise ActionController::RoutingError.new('Not Found') unless base
    other_user = User.find(params[:other_user_id])
    error_message = nil
    if current_user.company.master? || other_user.company_id==current_user.company_id || other_user.company.master?
      base.give_to other_user
      success = true
    else
      error_message = "You do not have permission to give this search to user with ID #{params[:other_user_id]}."
    end
    respond_to do |format|
      format.html {
        if error_message.blank?
          add_flash :notices, "Report #{base.name} has been given to #{other_user.full_name}."
          redirect_to Kernel.const_get(base.module_type)
        else
          error_redirect error_message
        end
      }
      format.json {
        if error_message.blank?
          render :json=>{"ok"=>"ok", "given_to" => other_user.full_name }
        else
          render :json=>{"error"=>error_message}, :status=>422
        end
      }
    end
  end
  def destroy
    base = SearchSetup.for_user(current_user).find(params[:id])
    name = base.name
    mod_type = Kernel.const_get(base.module_type)
    if base.destroy
      add_flash :notices, "#{name} successfully deleted."
    else 
      add_flash :errors, "#{name} could not be deleted."
    end
    redirect_to mod_type
  end
  def sticky_open
    current_user.update_attributes({:search_open=>true})
    render :text => ""
  end
  def sticky_close
    current_user.update_attributes({:search_open=>false})
    render :text => ""
  end

  private 
  def append_timezone_to_datetime p
    p[:search_setup][:search_criterions_attributes].each do |id, criterion|
      mf = ModelField.find_by_uid(criterion[:model_field_uid])
      if mf.data_type == :datetime && SearchCriterion.date_time_operators_requiring_timezone.include?(criterion[:operator])

        unless criterion[:value].nil? || criterion[:value].strip.length == 0
          criterion[:value] = criterion[:value] + " " + Time.zone.name
        end
      end
    end unless p[:search_setup][:search_criterions_attributes].nil? 
  end
end
