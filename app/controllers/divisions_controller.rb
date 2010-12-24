class DivisionsController < ApplicationController
	def create
		@company = Company.find(params[:company_id])
		action_secure(@company.can_edit?(current_user),@company,{:verb=>"create",:module_name=>"division"}) {
  		@division = @company.divisions.create(params[:division])
  		redirect_to company_path(@company)
    }
	end
	def edit
		@company = Company.find(params[:company_id])
		action_secure(@company.can_edit?(current_user),@company,{:verb=>"edit",:module_name=>"division"}) {
  		@countries = Country.all
  		@division = Division.find(params[:id])
  		render 'companies/show'
    }
	end
	
	def update
		@company = Company.find(params[:company_id])
		action_secure(@company.can_edit?(current_user),@company,{:verb=>"edit",:module_name=>"division"}) {
      @division = Division.find(params[:id])
      respond_to do |format|
        if @division.update_attributes(params[:division])
          add_flash :notices, "Division was updated successfully."
          format.html { redirect_to(@company) }
          format.xml  { head :ok }
        else
          errors_to_flash @division
          format.html { redirect_to edit_company_division_path(@company,@division) }
          format.xml  { render :xml => @division.errors, :status => :unprocessable_entity }
        end
      end
    }
  end
	
	
	def destroy
    @division = Division.find(params[:id])
    @company = Company.find(params[:company_id])
    action_secure(@company.can_edit?(current_user),@company,{:verb=>"delete",:module_name=>"division"}) {
	    @division.destroy
      errors_to_flash @division
      redirect_to company_path(@company)
    }
	end
end
