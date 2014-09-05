class DataCrossReferencesController < ApplicationController
  
  def index
    xref_type = params[:cross_reference_type]
    action_secure(DataCrossReference.can_view?(xref_type, current_user), nil, {:verb => "view", :lock_check => false, :module_name=>"cross reference type"}) do
      @xref_info = xref_hash xref_type, current_user
      @xrefs = DataCrossReference.where(cross_reference_type: xref_type).order("`key`").paginate(:per_page=>50,:page=>params[:page])
    end
  end

  def edit
    new_edit DataCrossReference.find(params[:id])
  end

  def new
    new_edit DataCrossReference.new(cross_reference_type: params[:cross_reference_type])
  end

  def update
    xref = DataCrossReference.find(params[:id])
    action_secure(xref.can_view?(current_user), xref, {:verb => "edit", :lock_check => false, :module_name=>"cross reference"}) do
      if xref.update_attributes params[:data_cross_reference]
        add_flash :notices, "Cross Reference was successfully updated."
        redirect_to data_cross_references_path(cross_reference_type: params[:data_cross_reference][:cross_reference_type])
      else
        @xref = xref
        @xref_info = xref_hash xref.cross_reference_type, current_user
        errors_to_flash xref, now: true
        render action: :edit
      end
    end
  end

  def create
    action_secure(DataCrossReference.can_view?(params[:data_cross_reference][:cross_reference_type], current_user), nil, {:verb => "create", :lock_check => false, :module_name=>"cross reference"}) do
      xref = DataCrossReference.new params[:data_cross_reference]
      if xref.save
        add_flash :notices, "Cross Reference was successfully created."
        redirect_to data_cross_references_path(cross_reference_type: params[:data_cross_reference][:cross_reference_type])
      else
        @xref = xref
        @xref_info = xref_hash xref.cross_reference_type, current_user
        errors_to_flash xref, now: true
        render action: :new
      end
    end
    
  end

  def destroy
    xref = DataCrossReference.find(params[:id])
    action_secure(xref.can_view?(current_user), xref, {:verb => "delete", :lock_check => false, :module_name=>"cross reference"}) do
      if xref.destroy
        add_flash :notices, "Cross Reference was successfully deleted."
        redirect_to data_cross_references_path(cross_reference_type: xref.cross_reference_type)
      else
        redirect_to edit_data_cross_reference_path(xref)
      end
    end
  end

  private

    def xref_hash xref_type, user
      info = DataCrossReference.xref_edit_hash user
      info[xref_type]
    end

    def new_edit xref
      action_secure(xref.can_view?(current_user), xref, {:verb => "edit", :lock_check => false, :module_name=>"cross reference"}) do
        @xref_info = xref_hash xref.cross_reference_type, current_user
        @xref = xref
      end
    end
end
