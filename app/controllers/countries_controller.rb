class CountriesController < ApplicationController
  # GET /countries
  # GET /countries.xml
  def index
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @countries }
    end
  end


  # GET /countries/1/edit
  def edit
    admin_secure("Only administrators can edit countries.") {
      @country = Country.find(params[:id])
    }
  end

  def show
    c = Country.find(params[:id])
    redirect_to edit_country_path(c)
  end

  # PUT /countries/1
  # PUT /countries/1.xml
  def update
    admin_secure("Only administrators can edit countries.") {
      @country = Country.find(params[:id])
      quicksearch_show = @country.quicksearch_show

      respond_to do |format|
        if @country.update_attributes(params[:country])
          add_flash :notices, "#{@country.name} was successfully updated."
          if quicksearch_show != @country.quicksearch_show
            add_flash :notices, "Your change to 'View in QuickSearch' will be reflected after the next server restart."
          end
          format.html { redirect_to(countries_path) }
          format.xml  { head :ok }
        else
          errors_to_flash @country, :now => true
          format.html { render :action => "edit" }
          format.xml  { render :xml => @country.errors, :status => :unprocessable_entity }
        end
      end
    }
  end
end
