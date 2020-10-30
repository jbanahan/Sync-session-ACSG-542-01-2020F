class PowerOfAttorneysController < ApplicationController
  def index
    permission = current_user.view_power_of_attorneys?
    @company = Company.find(params[:company_id])
    @power_of_attorneys = PowerOfAttorney.where(["company_id = ?", params[:company_id]]) if permission

    respond_to do |format|
      format.html do
        if !permission
          add_flash :errors, "You do not have permission to view powers of attorney."
          redirect_to(company_path(@company))
        else
          render
        end
      end
      format.xml  do
        if !permission
          render xml: "Forbidden", status: :unprocessable_entity
        else
          render xml: @power_of_attorneys
        end
      end
    end
  end

  # GET /power_of_attorneys/new
  # GET /power_of_attorneys/new.xml
  def new
    permission = current_user.edit_power_of_attorneys?
    @company = Company.find(params[:company_id])
    @power_of_attorney = @company.power_of_attorneys.build

    respond_to do |format|
      format.html do
        if permission
          render
        else
          add_flash :errors, "You do not have permission to create powers of attorney."
          redirect_to(company_path(@company))
        end
      end
      format.xml  do
        if !permission
          render xml: "Forbidden", status: :unprocessable_entity
        else
          render xml: @power_of_attorney
        end
      end
    end
  end

  def create
    permission = current_user.edit_power_of_attorneys?
    @power_of_attorney = PowerOfAttorney.new(permitted_params(params))
    @power_of_attorney.user = current_user
    @company = @power_of_attorney.company

    respond_to do |format|
      if permission && @power_of_attorney.save
        add_flash :notices, "Power of Attorney created successfully."
        format.html { redirect_to(company_power_of_attorneys_path(@company)) }
        format.xml  { render xml: @power_of_attorney, status: :created, location: @power_of_attorney }
      else
        if permission # rubocop:disable Style/IfInsideElse
          errors_to_flash @power_of_attorney, now: true
          @company = Company.find(params[:company_id])
          format.html { render action: "new" }
          format.xml  { render xml: @power_of_attorney.errors, status: :unprocessable_entity }
        else
          format.html do
            add_flash :errors, "You do not have permission to create powers of attorney."
            redirect_to(company_path(@company))
          end
          format.xml { render xml: "Forbidden", status: :unprocessable_entity }
        end
      end
    end
  end

  def destroy
    power_of_attorney = PowerOfAttorney.find(params[:id])
    c = power_of_attorney.company
    permission = current_user.edit_power_of_attorneys?
    power_of_attorney.destroy if permission

    respond_to do |format|
      format.html do
        if !permission
          add_flash :errors, "You do not have permission to delete powers of attorney."
          redirect_to(company_path(c))
        else
          redirect_to(company_power_of_attorneys_path(c))
        end
      end
      format.xml  do
        if permission
          head :ok
        else
          render xml: "Forbidden", status: :unprocessable_entity
        end
      end
    end
    nil
  end

  def download
    permission = current_user.view_power_of_attorneys?
    @power_of_attorney = PowerOfAttorney.where(id: params[:id]).first
    if permission
      if @power_of_attorney.nil?
        add_flash :errors, "File could not be found."
        redirect_to(companies_path)
      else
        send_data @power_of_attorney.attachment_data,
                  filename: @power_of_attorney.attachment_file_name,
                  type: @power_of_attorney.attachment_content_type,
                  disposition: 'attachment'
      end
    else
      add_flash :errors, "You do not have permission to view powers of attorney."
      redirect_to(companies_path)
    end
  end

  private

    def permitted_params(params)
      params.require(:power_of_attorney).permit(:start_date, :expiration_date, :company_id, :attachment, :attachment_file_name)
    end
end
