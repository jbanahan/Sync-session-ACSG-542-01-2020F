class CountriesController < ApplicationController
  # GET /countries
  # GET /countries.xml
  def index
    @countries = Country.all

		@country = Country.new
		
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @countries }
    end
  end

  # GET /countries/1
  # GET /countries/1.xml
  def show
    @country = Country.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @country }
    end
  end

  # GET /countries/new
  # GET /countries/new.xml
  def new
    @country = Country.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @country }
    end
  end

  # GET /countries/1/edit
  def edit
    @country = Country.find(params[:id])
  end

  # POST /countries
  # POST /countries.xml
  def create
    @country = Country.new(params[:country])
    respond_to do |format|
      if @country.save
				@countries = Country.all
				@country = Country.new
        format.html { render :action => "index" }
        format.xml  { render :xml => @country, :status => :created, :location => @country }
      else
        errors_to_flash @country, :now => true
        @countries = Country.all
        format.html { render :action => "index" }
        format.xml  { render :xml => @country.errors, :status => :unprocessable_entity }
      end
    end

  end

  # PUT /countries/1
  # PUT /countries/1.xml
  def update
    @country = Country.find(params[:id])

    respond_to do |format|
      if @country.update_attributes(params[:country])
        add_flash :notices, "Country was successfully updated."
        format.html { redirect_to(@country) }
        format.xml  { head :ok }
      else
        errors_to_flash @country, :now => true
        format.html { render :action => "edit" }
        format.xml  { render :xml => @country.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /countries/1
  # DELETE /countries/1.xml
  def destroy
    @country = Country.find(params[:id])
    @country.destroy

    respond_to do |format|
      errors_to_flash @country
      format.html { redirect_to(countries_url) }
      format.xml  { head :ok }
    end
  end
end
