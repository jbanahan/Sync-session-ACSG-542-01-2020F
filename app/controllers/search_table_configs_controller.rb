class SearchTableConfigsController < ApplicationController
  def set_page_title
    @page_title = 'Tools'
  end
  def index
    sys_admin_secure { @configs = SearchTableConfig.all }
  end

  def new
    sys_admin_secure {
      @config = SearchTableConfig.new
      @companies = Company.order(:name)
      render :new_edit
    }
  end

  def edit
    sys_admin_secure {
      @config = SearchTableConfig.find params[:id]
      @companies = Company.order(:name)
      render :new_edit
    }
  end

  def create
    sys_admin_secure {
      p = params[:search_table_config]
      SearchTableConfig.create!(page_uid: p[:page_uid], name: p[:name], config_json: p[:config_json], company_id: p[:company_id])
      redirect_to search_table_configs_path
    }
  end

  def update
    sys_admin_secure {
      stc = SearchTableConfig.find params[:id]
      p = params[:search_table_config]
      stc.update_attributes(page_uid: p[:page_uid], name: p[:name], config_json: p[:config_json], company_id: p[:company_id])
      redirect_to search_table_configs_path
    }
  end

  def destroy
    sys_admin_secure {
      stc = SearchTableConfig.find params[:id]
      stc.destroy
      redirect_to search_table_configs_path
    }
  end
end
