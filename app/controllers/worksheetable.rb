module Worksheetable

  def import_worksheet
    @obj = root_class.find(params[:id])
    action_secure(@obj.can_edit?(current_user),@obj,{:verb => "import worksheet for",:module_name=>"item"}) {
      process_worksheet @obj
      errors_to_flash @obj
      redirect_to @obj      
    }
  end

  def import_new_worksheet
    @obj = root_class.new
    action_secure(@obj.can_create?(current_user),@obj,{:lock_check=>false,:verb=>"import worksheet for",:module_name=>"item"}) {
      process_worksheet @obj
      errors_to_flash @obj
      redirect_to @obj
    }
  end

  private
  def process_worksheet(obj)
    w = params[:worksheet]
    wc = WorksheetConfig.find(params[:worksheet_config_id])
    if wc.nil?
      add_flash :errors, "Worksheet Setup with ID \"#{params[:worksheet_config_id]}\" was not found.", :now => true
      return
    end
    wc.process obj, w.tempfile.path
    add_flash :notices, "Your worksheet was loaded successfully." , :now => true
  end
  
end
