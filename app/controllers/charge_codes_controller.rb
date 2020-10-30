class ChargeCodesController < ApplicationController
  def set_page_title
    @page_title = 'Tools'
  end

  def index
    admin_secure do
      @charge_codes = ChargeCode.order("code ASC")
    end
  end

  def create
    admin_secure do
      c = ChargeCode.find_by(code: params[:charge_code][:code])
      if c
        error_redirect "A charge code with code \"#{c.code}\" already exists."
      else
        errors_to_flash ChargeCode.create(permitted_params(params))
      end
      redirect_to ChargeCode
    end
  end

  def destroy
    admin_secure do
      c = ChargeCode.find params[:id]
      if c
        c.destroy
        add_flash :notices, "Charge code #{c.code} deleted."
      else
        add_flash :errors, "Charge code not found."
      end
      redirect_to ChargeCode
    end
  end

  def update
    admin_secure do
      c = ChargeCode.find params[:id]
      if c
        c.update(permitted_params(params))
        add_flash :notices, "Charge code #{c.code} updated."
      else
        add_flash :errors, "Charge code not found."
      end
      redirect_to ChargeCode
    end
  end
end

private
def permitted_params(params)
  params.require(:charge_code).permit(:apply_hst, :code, :description)
end