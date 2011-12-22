class PowerOfAttorneysController < ApplicationController
  # GET /power_of_attorneys
  # GET /power_of_attorneys.xml
  def index
    @power_of_attorneys = PowerOfAttorney.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @power_of_attorneys }
    end
  end

  # GET /power_of_attorneys/1
  # GET /power_of_attorneys/1.xml
  def show
    @power_of_attorney = PowerOfAttorney.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @power_of_attorney }
    end
  end

  # GET /power_of_attorneys/new
  # GET /power_of_attorneys/new.xml
  def new
    @power_of_attorney = PowerOfAttorney.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @power_of_attorney }
    end
  end

  # GET /power_of_attorneys/1/edit
  def edit
    @power_of_attorney = PowerOfAttorney.find(params[:id])
  end

  # POST /power_of_attorneys
  # POST /power_of_attorneys.xml
  def create
    @power_of_attorney = PowerOfAttorney.new(params[:power_of_attorney])

    respond_to do |format|
      if @power_of_attorney.save
        format.html { redirect_to(@power_of_attorney, :notice => 'Power of attorney was successfully created.') }
        format.xml  { render :xml => @power_of_attorney, :status => :created, :location => @power_of_attorney }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @power_of_attorney.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /power_of_attorneys/1
  # PUT /power_of_attorneys/1.xml
  def update
    @power_of_attorney = PowerOfAttorney.find(params[:id])

    respond_to do |format|
      if @power_of_attorney.update_attributes(params[:power_of_attorney])
        format.html { redirect_to(@power_of_attorney, :notice => 'Power of attorney was successfully updated.') }
        format.xml  { head :ok }
      else
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
      format.html { redirect_to(power_of_attorneys_url) }
      format.xml  { head :ok }
    end
  end
end
