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
      error_redirect "Search wtih ID #{params[:id]} not found."
    else
      search_setup.search_columns.destroy_all #clear, they will be reloaded
      search_setup.sort_criterions.destroy_all #clear, they will be reloaded
      search_setup.touch(false)
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
      base.deep_copy(new_name,true).touch(true)
      redirect_to Kernel.const_get(base.module_type)
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
end
