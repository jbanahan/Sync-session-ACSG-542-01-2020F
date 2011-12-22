class PowerOfAttorneysController < ApplicationController
  # GET /power_of_attorneys
  # GET /power_of_attorneys.xml
  def index
    @company = Company.find(params[:company_id])
    @power_of_attorneys = PowerOfAttorney.where(["company_id = ?", params[:company_id]])

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @power_of_attorneys }
    end
  end

  # GET /power_of_attorneys/1
  # GET /power_of_attorneys/1.xml
  def show
    @power_of_attorney = PowerOfAttorney.find(params[:id])
    redirect_to edit_company_power_of_attorney_path @power_of_attorney
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

  # GET /power_of_attorneys/1/edit
  def edit
    @power_of_attorney = PowerOfAttorney.find(params[:id])
    @company = @power_of_attorney.company
  end

  # POST /power_of_attorneys
  # POST /power_of_attorneys.xml
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

  # PUT /power_of_attorneys/1
  # PUT /power_of_attorneys/1.xml
  def update
    @power_of_attorney = PowerOfAttorney.find(params[:id])
    @power_of_attorney.user = current_user
    @company = @power_of_attorney.company

    respond_to do |format|
      if @power_of_attorney.update_attributes(params[:power_of_attorney])
        add_flash :notices, "Power of Attorney updated successfully."
        format.html { redirect_to(company_power_of_attorneys_path(@company)) }
        format.xml  { head :ok }
      else
        errors_to_flash @power_of_attorney
        format.html { render :action => "edit" }
        format.xml  { render :xml => @power_of_attorney.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /power_of_attorneys/1
  # DELETE /power_of_attorneys/1.xml
  def destroy
    @power_of_attorney = PowerOfAttorney.find(params[:id])
    @power_of_attorney.destroy

    respond_to do |format|
      format.html { redirect_to(company_power_of_attorneys_path(@company)) }
      format.xml  { head :ok }
    end
  end
end
