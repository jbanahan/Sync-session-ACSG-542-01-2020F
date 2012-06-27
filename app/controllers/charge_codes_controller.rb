class ChargeCodesController < ApplicationController
  def index
    admin_secure {
      @charge_codes = ChargeCode.order("code ASC")
    }
  end
  def create
    admin_secure {
      c = ChargeCode.find_by_code params[:charge_code][:code]
      if c
        error_redirect "A charge code with code \"#{c.code}\" already exists."
      else
        errors_to_flash ChargeCode.create params[:charge_code]
      end
      redirect_to ChargeCode
    }
  end
  def destroy
    admin_secure {
      c = ChargeCode.find params[:id]
      if c
        c.destroy
        add_flash :notices, "Charge code #{c.code} deleted."
      else
        add_flash :errors, "Charge code not found."
      end
      redirect_to ChargeCode
    }
  end
  def update
    admin_secure {
      c = ChargeCode.find params[:id]
      if c
        c.update_attributes params[:charge_code]
        add_flash :notices, "Charge code #{c.code} updated."
      else
        add_flash :errors, "Charge code not found."
      end
      redirect_to ChargeCode
    }
  end
end
