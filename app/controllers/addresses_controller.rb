class AddressesController < ApplicationController
  include ActiveSupport
  before_filter :require_user
	
	def create
		@address = Address.new(params[:address])
		@company = @address.company
		action_secure(@company.can_edit?(current_user),@company,{:verb=>"create",:module_name=>"address"}) {
		  @address.save
  		errors_to_flash @address
  		redirect_to company_path(@company)
    }
	end
	
	def render_partial
		@ad = Address.find(params[:id])
		respond_to do |format|
		  format.html {render :partial => 'display', :locals => { :ad => @ad, :address_id => params[:div_name] }}
		  format.json {render :json => @ad.to_json(:include =>{:country => {:only => :name}})}
	  end
	end
	
	def destroy
		@ad = Address.find(params[:id])
    @company = @ad.company
    action_secure(@company.can_edit?(current_user),@company,{:verb=>"delete",:module_name=>"address"}) {
      @ad.destroy
      errors_to_flash @ad
      redirect_to company_path(@company)
    }
	end
	
	def edit
		@countries = Country.all
		a = Address.find(params[:id])
		@company = a.company
    action_secure(@company.can_edit?(current_user),@company,{:verb=>"edit",:module_name=>"address"}) {
		  @address = a
  		render 'companies/show'
		}
	end
	
	def update
    @address = Address.find(params[:id])
		@company = @address.company
    action_secure(@company.can_edit?(current_user),@company,{:verb=>"edit",:module_name=>"address"}) {
      respond_to do |format|
        if @address.update_attributes(params[:address])
          add_flash :notices, "Address updated successfully."
          format.html { redirect_to(@company) }
          format.xml  { head :ok }
        else
          errors_to_flash @address
          format.html { redirect_to edit_company_address_path(@company,@address) }
          format.xml  { render :xml => @address.errors, :status => :unprocessable_entity }
        end
      end
    }
	end
end
