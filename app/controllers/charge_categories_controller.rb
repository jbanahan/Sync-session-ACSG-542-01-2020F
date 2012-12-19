class ChargeCategoriesController < ApplicationController

  def index
    admin_secure do
      @company = Company.find params[:company_id]
      @charge_categories = @company.charge_categories  
    end
  end

  def create
    admin_secure do
      c = Company.find(params[:company_id]).charge_categories.create(params[:charge_category])
      errors_to_flash c
      add_flash :notices, "Charge Category created successfully." if c.errors.empty?
      redirect_to company_charge_categories_path(c.company)
    end
  end

  def destroy
    admin_secure do
      if ChargeCategory.find(params[:id]).destroy
        add_flash :notices, "Charge Category deleted."
        redirect_to company_charge_categories_path(Company.find(params[:company_id]))
      end
    end
  end

end
