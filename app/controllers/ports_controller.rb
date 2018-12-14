class PortsController < ApplicationController
  SEARCH_PARAMS = {
    'p_name'=>{:field=>'name',:label=>'Name'},
    'p_k_code'=>{:field=>'schedule_k_code',:label=>'Schedule K Code'},
    'p_d_code'=>{:field=>'schedule_d_code',:label=>'Schedule D Code'},
    'p_cp_code'=>{:field=>'cbsa_port',:label=>'CBSA Port'},
    'p_cs_code'=>{:field=>'cbsa_sublocation',:label=>'CBSA Sublocation'},
    'p_un_code'=>{:field=>'unlocode',:label=>'UN/LOCODE'},
    'p_iata'=>{field: "iata_code", label: "IATA Code"}
  }
  def set_page_title
    @page_title = 'Tools'
  end
  def index
    admin_secure {
      @ports = build_search(SEARCH_PARAMS,'p_name','p_name').paginate(:per_page=>50,:page=>params[:page])
      render :layout=>'one_col'
    }
  end

  def update
    admin_secure {
      p = Port.find params[:id]
      nullify_blank_code_attributes
      p.update_attributes(params[:port])
      errors_to_flash p
      add_flash :notices, "Port created successfully." if flash[:errors].blank?
      redirect_to request.referrer
    }
  end

  def create
    admin_secure {
      nullify_blank_code_attributes
      errors_to_flash Port.create(params[:port])
      add_flash :notices, "Port created successfully." if flash[:errors].blank?
      redirect_to request.referrer
    }
  end

  def destroy
    admin_secure {
      errors_to_flash Port.find(params[:id]).destroy
      add_flash :notices, "Port deleted successfully." if flash[:errors].blank?
      redirect_to request.referrer
    }
  end

  def secure 
    current_user.admin? ? Port.where('1=1') : Port.where('1=0')
  end

  private 
    def nullify_blank_code_attributes
      # This is needed so the Port Code model field uses the correct field (without needing a massive case statement and length checking)
      params["port"]["schedule_d_code"] = nil if params["port"]["schedule_d_code"].blank?
      params["port"]["schedule_k_code"] = nil if params["port"]["schedule_k_code"].blank?
      params["port"]["unlocode"] = nil if params["port"]["unlocode"].blank?
      params["port"]["cbsa_port"] = nil if params["port"]["cbsa_port"].blank?
    end
end
