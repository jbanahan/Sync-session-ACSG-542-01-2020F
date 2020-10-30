class SpecialTariffCrossReferencesController < ApplicationController

  SEARCH_PARAMS = {
    'c_hts_number' => { field: 'hts_number', label: 'HTS Number'},
    'c_special_hts_number' => { field: 'special_hts_number', label: 'Special HTS Number'},
    'c_country_origin_iso' => {field: 'country_origin_iso', label: 'Country of Origin ISO Code'},
    'c_import_country_iso' => {field: 'import_country_iso', label: 'Country of Import ISO Code'},
    'c_special_tariff_type' => {field: 'special_tariff_type', label: 'Special Tariff Type'}
  }.freeze

  def root_class
    SpecialTariffCrossReference
  end

  def index
    admin_secure do
      sp = SEARCH_PARAMS.clone
      s = build_search(sp, 'c_country_origin_iso', 'c_special_tariff_type', 'd')
      respond_to do |format|
        format.html do
          distribute_reads { @special_tariffs = s.paginate(per_page: 40, page: params[:page]).to_a }
        end
      end
    end
  end

  def edit
    admin_secure do
      @countries = Country.all
      @special_tariff = SpecialTariffCrossReference.find(params[:id])
      respond_to do |format|
        format.html
      end
    end
  end

  def update
    admin_secure do
      @special_tariff = SpecialTariffCrossReference.where(id: params[:id]).first
      redirect_to special_tariff_cross_references_path if @special_tariff.blank?

      @special_tariff.update(permitted_params(params))
      if @special_tariff.valid?
        add_flash :notices, "Special Tariff #{@special_tariff.hts_number} has been updated"
        redirect_to special_tariff_cross_references_path
      else
        errors_to_flash @special_tariff
        render action: "edit"
      end
    end
  end

  def download
    admin_secure do
      OpenChain::SpecialTariffCrossReferenceHandler.delay.send_tariffs(current_user.id)
      add_flash :notices, "Special Tariff download has been queued. You will receive an email when it completes."
      redirect_to special_tariff_cross_references_path
    end
  end

  def upload
    f = CustomFile.new(file_type: 'OpenChain::SpecialTariffCrossReferenceHandler', uploaded_by: current_user, attached: params[:attached])
    admin_secure do
      if params[:attached].nil?
        add_flash :errors, "You must select a file to upload."
      end

      if !has_errors? && f.save
        CustomFile.delay.process f.id, current_user.id
        add_flash :notices, "Upload successful. You will receive a message when the upload is processed."
      else
        errors_to_flash f
      end

      redirect_to special_tariff_cross_references_path
    end
  end

  private

  def secure
    SpecialTariffCrossReference.find_can_view(current_user)
  end

  def permitted_params(params)
    params.require(:special_tariff_cross_reference)
          .permit(:attached, :country_origin_iso, :effective_date_end, :effective_date_start, :hts_number, :import_country_iso,
                  :priority, :special_hts_number, :special_tariff_type, :suppress_from_feeds)
  end
end
