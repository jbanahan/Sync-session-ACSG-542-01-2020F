class PortsController < ApplicationController
  SEARCH_PARAMS = {
    'p_name'=>{:field=>'name', :label=>'Name'},
    'p_k_code'=>{:field=>'schedule_k_code', :label=>'Schedule K Code'},
    'p_d_code'=>{:field=>'schedule_d_code', :label=>'Schedule D Code'},
    'p_cp_code'=>{:field=>'cbsa_port', :label=>'CBSA Port'},
    'p_cs_code'=>{:field=>'cbsa_sublocation', :label=>'CBSA Sublocation'},
    'p_un_code'=>{:field=>'unlocode', :label=>'UN/LOCODE'},
    'p_iata'=>{field: "iata_code", label: "IATA Code"}
  }
  def set_page_title
    @page_title = 'Tools'
  end
  def index
    admin_secure {
      @ports = build_search(SEARCH_PARAMS, 'p_name', 'p_name').paginate(:per_page=>50, :page=>params[:page])
      render :layout=>'one_col'
    }
  end

  def update
    admin_secure {
      p = Port.find params[:id]
      nullify_blank_code_attributes
      save_port(params, p)
      errors_to_flash p
      add_flash :notices, "Port successfully updated." if flash[:errors].blank?
      redirect_to request.referrer
    }
  end

  def create
    admin_secure {
      nullify_blank_code_attributes
      errors_to_flash(save_port(params, Port.new))
      add_flash :notices, "Port successfully created." if flash[:errors].blank?
      redirect_to request.referrer
    }
  end

  def destroy
    admin_secure {
      errors_to_flash Port.find(params[:id]).destroy
      add_flash :notices, "Port successfully deleted." if flash[:errors].blank?
      redirect_to request.referrer
    }
  end

  def secure
    current_user.admin? ? Port.where('1=1') : Port.where('1=0')
  end

  private
    def nullify_blank_code_attributes
      # This is needed so the Port Code model field uses the correct field (without needing a massive case statement and length checking)
      [:schedule_k_code, :schedule_d_code, :unlocode, :cbsa_port, :cbsa_sublocation, :iata_code].each do |k|
        params[:port][k] = nil if params[:port][k].blank?
      end
    end

    def save_port params, port
      port_params = params[:port]
      address_params = params[:port].delete(:address) if params[:port][:address]
      Port.transaction do
        port.update port_params
        handle_address port, address_params
      end
      port
    end

    def handle_address port, address_params
      return if address_params.blank?

      compacted = address_params.delete_if {|k, v| v.blank? || k == "id" }
      # Delete the backing address record if id is the only thing that's not blank
      if compacted.blank?
        port.address.destroy if port.address
      else
        country_iso = address_params.delete :country_iso_code
        country = Country.find_by(iso_code: country_iso) unless country_iso.blank?
        if country_iso.present? && country.nil?
          port.errors[:base] = "Invalid Country ISO '#{country_iso}'."
          raise ActiveRecord::Rollback
        else
          address_params[:country_id] = country&.id if country
          address = port.address
          address = port.build_address if address.nil?
          address.update address_params
        end
      end
      nil
    end
end
