require 'open_chain/fiscal_month_uploader'

class FiscalMonthsController < ApplicationController

  before_action :company_enabled?

  def index
    sys_admin_secure do
      @fiscal_months = FiscalMonth.where(company_id: params[:company_id]).order("year DESC, month_number DESC")
      @company = Company.find params[:company_id]
    end
  end

  def new
    sys_admin_secure do
      @company = Company.find params[:company_id]
      @fiscal_month = @company.fiscal_months.new
    end
  end

  def edit
    sys_admin_secure do
      @fiscal_month = FiscalMonth.find(params[:id])
      @company = Company.find @fiscal_month.company_id
    end
  end

  def create
    sys_admin_secure do
      @company = Company.find(params[:fiscal_month][:company_id])
      @company.fiscal_months.create!(permitted_params(params))
      redirect_to company_fiscal_months_path(@company)
    end
  end

  def update
    sys_admin_secure do
      @company = Company.find(params[:company_id])
      fm = @company.fiscal_months.find(params[:id])
      fm.update(permitted_params(params))
      redirect_to company_fiscal_months_path(@company)
      add_flash :notices, "Fiscal month updated."
    end
  end

  def destroy
    sys_admin_secure do
      @company = Company.find(params[:company_id])
      @company.fiscal_months.find(params[:id]).destroy
      redirect_to company_fiscal_months_path(@company)
      add_flash :notices, "Fiscal month deleted."
    end
  end

  def download
    sys_admin_secure do
      co = Company.find params[:company_id]
      csv = FiscalMonth.generate_csv co.id
      filename = "#{co.name}_fiscal_months_#{Time.zone.today.strftime("%m-%d-%Y")}.csv"
      send_data csv, filename: filename, type: 'text/csv', disposition: "attachment"
    end
  end

  def upload
    sys_admin_secure do
      co_id = params[:company_id].to_i
      file = params[:attached]
      if file.blank?
        add_flash :errors, "You must select a file to upload."
      else
        ext = File.extname(file.original_filename)
        run_uploader ext, co_id, file, current_user
      end
      redirect_to company_fiscal_months_path co_id
    end
  end

  def company_enabled?
    if params[:company_id]
      co = Company.find params[:company_id]
    else
      co = Company.find(params[:fiscal_month][:company_id])
    end
    unless co.fiscal_reference.presence
      add_flash :errors, "This company doesn't have its fiscal calendar enabled."
      redirect_to company_path(co)
      nil
    end
  end

  private

  def run_uploader ext, co_id, file, user
    if [".CSV", ".XLS", ".XLSX"].include? ext.upcase
      cf = CustomFile.create!(file_type: 'OpenChain::FiscalMonthUploader', uploaded_by: user, attached: file)
      CustomFile.process(cf.id, current_user.id, company_id: co_id)
      add_flash :notices, "Fiscal months uploaded."
    else
      add_flash :errors, "Only XLS, XLSX, and CSV files are accepted."
    end
  end

  def permitted_params(params)
    params.require(:fiscal_month).except(:company_id).permit(:end_date, :month_number, :start_date, :year)
  end

end
