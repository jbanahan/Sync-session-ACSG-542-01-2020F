class WorksheetConfigsController < ApplicationController
  def index
    admin_secure {
      @worksheet_configs = WorksheetConfig.all    
      render 'index', :layout => 'one_col'
    }
  end

  def show
    redirect_to edit_worksheet_config_path params[:id]
  end

  def edit
    admin_secure {
      @wc = WorksheetConfig.find(params[:id])
    }
  end

  def new
    admin_secure {
      @wc = WorksheetConfig.new
    }
  end

  def create 
    admin_secure {
      w = WorksheetConfig.create(params[:worksheet_config])
      errors_to_flash w
      redirect_to edit_worksheet_config_path(w)
    }
  end

  def update
    admin_secure {
      w = WorksheetConfig.find(params[:id])
      if w.update_attributes(params[:worksheet_config])
        add_flash :notices, "Worksheet Setup updated successfully."
      end
      errors_to_flash w
      redirect_to edit_worksheet_config_path(w)
    }
  end

  def destroy
    admin_secure {
      w = WorksheetConfig.find(params[:id])
      if w.destroy
        add_flash :notices, "Worksheet Setup deleted successfully."
        redirect_to worksheet_configs_path
      else
        errors_to_flash w
        redirect_to edit_worksheet_config_path
      end
    }
  end
end
