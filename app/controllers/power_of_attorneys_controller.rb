class PowerOfAttorneysController < ApplicationController
  def index
    @company = Company.find(params[:company_id])
    @power_of_attorneys = PowerOfAttorney.where(["company_id = ?", params[:company_id]])

    respond_to do |format|
      format.html { render  }
      format.xml  { render :xml => @power_of_attorneys }
    end
  end

  # GET /power_of_attorneys/new
  # GET /power_of_attorneys/new.xml
  def new
    @company = Company.find(params[:company_id])
    @power_of_attorney = @company.power_of_attorneys.build

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @power_of_attorney }
    end
  end

  def create
    @power_of_attorney = PowerOfAttorney.new(params[:power_of_attorney])
    @power_of_attorney.user = current_user
    @company = @power_of_attorney.company

    respond_to do |format|
      if @power_of_attorney.save
        add_flash :notices, "Power of Attorney created successfully."
        format.html { redirect_to(company_power_of_attorneys_path(@company)) }
        format.xml  { render :xml => @power_of_attorney, :status => :created, :location => @power_of_attorney }
      else
        errors_to_flash @power_of_attorney, :now => true
        @company = Company.find(params[:company_id])
        format.html { render :action => "new" }
        format.xml  { render :xml => @power_of_attorney.errors, :status => :unprocessable_entity }
      end
    end
  end

  def destroy
    power_of_attorney = PowerOfAttorney.find(params[:id])
    c = power_of_attorney.company 
    power_of_attorney.destroy

    respond_to do |format|
      format.html { redirect_to(company_power_of_attorneys_path(c)) }
      format.xml  { head :ok }
    end
  end

  def download
    @power_of_attorney = PowerOfAttorney.find(params[:id])
    if @power_of_attorney.nil?
      add_flash :errors, "File could not be found."
      redirect_to request.referrer
    else
      send_data @power_of_attorney.attachment_data, 
      :filename => @power_of_attorney.attachment_file_name,
      :type => @power_of_attorney.attachment_content_type,
      :disposition => 'attachment'
    end
  end

end
