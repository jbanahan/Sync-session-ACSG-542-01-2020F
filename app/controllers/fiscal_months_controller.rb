require 'open_chain/fiscal_month_uploader'

class FiscalMonthsController < ApplicationController

  before_filter :company_enabled?

  def index
    sys_admin_secure {
      @fiscal_months = FiscalMonth.where(company_id: params[:company_id]).order("year DESC, month_number DESC")
      @company = Company.find params[:company_id]
    }
  end

  def new
    sys_admin_secure {
      @fiscal_month = FiscalMonth.new(company_id: params[:company_id])
      @company = Company.find params[:company_id]
    }
  end

  def edit
    sys_admin_secure {
      @fiscal_month = FiscalMonth.find(params[:id])
      @company = Company.find @fiscal_month.company_id
    }
  end

  def create
    sys_admin_secure {
      fm_params = params[:fiscal_month]
      FiscalMonth.create! fm_params
      redirect_to company_fiscal_months_path(fm_params[:company_id])
    }
  end

  def update
    sys_admin_secure {
      fm = FiscalMonth.find params[:id]
      fm.update_attributes params[:fiscal_month]
      redirect_to company_fiscal_months_path(params[:company_id])
      add_flash :notices, "Fiscal month updated."
    }
  end

  def destroy
    sys_admin_secure {
      FiscalMonth.find(params[:id]).destroy
      redirect_to company_fiscal_months_path(params[:company_id])
      add_flash :notices, "Fiscal month deleted."
    }
  end

  def download
    sys_admin_secure {
      co = Company.find params[:company_id]
      csv = FiscalMonth.generate_csv co.id
      filename = "#{co.name}_fiscal_months_#{Date.today.strftime("%m-%d-%Y")}.csv"
      send_data csv, filename: filename, type: 'text/csv', disposition: "attachment"
    }
  end

  def upload
    sys_admin_secure {
      co_id = params[:company_id].to_i
      file = params[:attached]
      if file.nil?
        add_flash :errors, "You must select a file to upload."
      else
        ext = File.extname(file.original_filename)
        run_uploader ext, co_id, file, current_user
      end
      redirect_to company_fiscal_months_path co_id
    }
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
      return
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


end
