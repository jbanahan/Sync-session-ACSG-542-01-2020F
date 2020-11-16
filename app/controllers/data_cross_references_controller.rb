require 'open_chain/data_cross_reference_uploader'

class DataCrossReferencesController < ApplicationController
  def index
    xref_type = params[:cross_reference_type]
    action_secure(DataCrossReference.can_view?(xref_type, current_user), nil, {verb: "view", lock_check: false, module_name: "cross reference type"}) do
      @xref_info = xref_hash xref_type, current_user

      distribute_reads do
        xrefs = build_search search_params(xref_type), 'd_key', 'd_key'
        @xrefs = xrefs.paginate(per_page: 50, page: params[:page]).to_a
      end

      @companies = if @xref_info[:require_company] == true && @xref_info[:company].present?
                     Company.where(system_code: @xref_info[:company][:system_code])
                   elsif @xref_info[:require_company] == true && @xref_info[:company].blank?
                      get_importers_for(current_user)
                   else
                      []
                   end
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

    action_secure(xref.can_view?(current_user), xref, {verb: "edit", lock_check: false, module_name: "cross reference"}) do
      company_id = params[:data_cross_reference][:company_id]
      company = Company.find(company_id) if company_id.present?

      xref.assign_attributes(permitted_attributes(params))
      xref.company = company

      if xref_hash(xref.cross_reference_type, current_user)[:require_company] && company.nil?
        add_flash(:errors, "You must assign a company.")
      elsif validate_non_duplicate(xref) && xref.save
        add_flash :notices, "Cross Reference was successfully updated."
        redirect_to data_cross_references_path(cross_reference_type: params[:data_cross_reference][:cross_reference_type])
        return
      else
        errors_to_flash xref, now: true
      end
      @xref = xref
      @xref_info = xref_hash xref.cross_reference_type, current_user
      render action: :edit
    end
  end

  def create
    action_secure(DataCrossReference.can_view?(params[:data_cross_reference][:cross_reference_type], current_user),
                  nil, {verb: "create", lock_check: false, module_name: "cross reference"}) do
      company_id = params[:data_cross_reference][:company_id]
      company = Company.find(company_id) if company_id.present?

      xref = DataCrossReference.new(permitted_attributes(params))
      xref.company = company

      if xref_hash(xref.cross_reference_type, current_user)[:require_company] && xref.company.nil?
        error_redirect "You must assign a company."
      elsif validate_non_duplicate(xref) && xref.save
        add_flash :notices, "Cross Reference was successfully created."
        redirect_to data_cross_references_path(cross_reference_type: params[:data_cross_reference][:cross_reference_type])
      else
        @xref = xref
        @xref_info = xref_hash xref.cross_reference_type, current_user
        errors_to_flash xref
        redirect_to new_data_cross_reference_path(cross_reference_type: params[:data_cross_reference][:cross_reference_type])
      end
    end
  end

  def destroy
    xref = DataCrossReference.find(params[:id])
    action_secure(xref.can_view?(current_user), xref, {verb: "delete", lock_check: false, module_name: "cross reference"}) do
      if xref.destroy
        add_flash :notices, "Cross Reference was successfully deleted."
        redirect_to data_cross_references_path(cross_reference_type: xref.cross_reference_type)
      else
        redirect_to edit_data_cross_reference_path(xref)
      end
    end
  end

  def download
    xref_type = params[:cross_reference_type]
    if DataCrossReference.can_view?(xref_type, current_user)
      csv = DataCrossReference.generate_csv xref_type, current_user
      filename = "xref_#{xref_type}_#{Time.zone.today.strftime("%m-%d-%Y")}.csv"
      send_data csv, filename: filename, type: 'text/csv', disposition: "attachment"
    else
      error_redirect "You do not have permission to download this file."
    end
  end

  def upload
    xref_type = params[:cross_reference_type]
    file = params[:attached]
    if DataCrossReference.can_view?(xref_type, current_user)
      run_uploader current_user, file, xref_type
      redirect_to request.referer
    else
      error_redirect "You do not have permission to update this cross reference."
    end
  end

  def get_importers_for(user)
    Company.search_secure(user, Company.importers.where("system_code IS NOT NULL AND system_code <> ''")).order('companies.name')
  end

  private

  def run_uploader user, file, xref_type
    uploader = OpenChain::DataCrossReferenceUploader
    if file.nil?
      add_flash :errors, "You must select a file to upload."
    else
      error = uploader.check_extension(file.original_filename)
      if error
        add_flash(:errors, error)
        return
      end
      cf = CustomFile.create!(file_type: uploader.to_s, uploaded_by: user, attached: file)
      CustomFile.delay.process(cf.id, current_user.id, cross_reference_type: xref_type, company_id: params[:company])
      add_flash(:notices, "Your file is being processed.  You'll receive a " + MasterSetup.application_name + " message when it completes.")
    end
  end

  def xref_hash xref_type, user
    info = DataCrossReference.xref_edit_hash user
    info[xref_type]
  end

  def new_edit xref
    action_secure(xref.can_view?(current_user), xref, {verb: "edit", lock_check: false, module_name: "cross reference"}) do
      @xref_info = xref_hash xref.cross_reference_type, current_user
      @xref = xref
      @importers = get_importers_for(current_user)
    end
  end

  def search_params xref_type
    edit_hash = xref_hash xref_type, current_user

    sp = {
      'd_key' => {field: "`key`", label: edit_hash[:key_label]}
    }

    if edit_hash[:show_value_column]
      sp['d_value'] = {field: "`value`", label: edit_hash[:value_label]}
    end

    sp
  end

  def secure
    # The xref param has already been validation in the index action prior to this method being
    # called so we're ok to always assume its presence
    DataCrossReference.where(cross_reference_type: params[:cross_reference_type])
  end

  def validate_non_duplicate xref
    edit_hash = DataCrossReference.xref_edit_hash current_user

    allow_save = true
    # See if we may allow duplicate xref keys..(some instances may require duplicates - though likely not via the screen edits)
    if !edit_hash[xref.cross_reference_type].try(:[], :allow_duplicate_keys)

      query = DataCrossReference.where(cross_reference_type: xref.cross_reference_type, company_id: xref.company_id, key: xref.key)
      if xref.id.try(:nonzero?)
        query = query.where("id <> ?", xref.id)
      end

      allow_save = query.first.nil?
      xref.errors.add(:base, "The #{edit_hash[xref.cross_reference_type][:key_label]} value '#{xref.key}' already exists on another cross reference record.") unless allow_save
    end

    allow_save
  end

  def permitted_attributes(params)
    params.require(:data_cross_reference).except(:company_id).permit(:cross_reference_type, :key, :value)
  end
end
