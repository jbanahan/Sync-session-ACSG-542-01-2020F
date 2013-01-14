class SearchSetupsController < ApplicationController
  
  def show
    search_setup = SearchSetup.for_user(current_user).find(params[:id])
    respond_to do |format|
      format.json { render :json => search_setup.to_json(:include => {:search_columns=>{:only=>[:model_field_uid,:rank]}, 
          :sort_criterions=>{:only=>[:model_field_uid,:rank,:descending]}}) }
    end 
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
      error_redirect "Search with ID #{params[:id]} not found."
    else
      new_name = params[:new_name]
      new_name = "Copy of #{base.name}" if new_name.empty?
      base.deep_copy(new_name).touch
      redirect_to Kernel.const_get(base.module_type)
    end
  end
  def give
    base = SearchSetup.for_user(current_user).find(params[:id])
    if base.nil?
      error_redirect "Search with ID #{params[:id]} not found."
    else
      other_user = User.find(params[:other_user_id])
      if current_user.company.master? || other_user.company_id==current_user.company_id || other_user.company.master?
        base.give_to other_user
        add_flash :notices, "Report #{base.name} has been given to #{other_user.full_name}."
        redirect_to Kernel.const_get(base.module_type)
      else
        error_redirect "You do not have permission to give this search to user with ID #{params[:other_user_id]}."
      end
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
    end 
  end
end
