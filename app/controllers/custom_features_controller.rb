require 'open_chain/s3'
require 'open_chain/custom_handler/ci_load_handler'
require 'open_chain/custom_handler/ecellerate_shipment_activity_parser'
require 'open_chain/custom_handler/eddie_bauer/eddie_bauer_fenix_invoice_handler'
require 'open_chain/custom_handler/fenix_commercial_invoice_spreadsheet_handler'
require 'open_chain/custom_handler/intacct/alliance_day_end_handler'
require 'open_chain/custom_handler/j_crew_parts_extract_parser'
require 'open_chain/custom_handler/kewill_isf_manual_parser'
require 'open_chain/custom_handler/lands_end/le_returns_parser'
require 'open_chain/custom_handler/lands_end/le_returns_commercial_invoice_generator'
require 'open_chain/custom_handler/lenox/lenox_shipment_status_parser'
require 'open_chain/custom_handler/lumber_liquidators/lumber_epd_parser'
require 'open_chain/custom_handler/lumber_liquidators/lumber_order_closer'
require 'open_chain/custom_handler/polo_csm_sync_handler'
require 'open_chain/custom_handler/polo/polo_ca_invoice_handler'
require 'open_chain/custom_handler/polo/polo_fiber_content_parser'
require 'open_chain/custom_handler/polo_sap_bom_handler'
require 'open_chain/custom_handler/under_armour/ua_tbd_report_parser'
require 'open_chain/custom_handler/under_armour/ua_winshuttle_product_generator'
require 'open_chain/custom_handler/under_armour/ua_winshuttle_schedule_b_generator'
require 'open_chain/custom_handler/under_armour/ua_style_color_region_parser'
require 'open_chain/custom_handler/under_armour/ua_style_color_factory_parser'
require 'open_chain/custom_handler/fisher/fisher_commercial_invoice_spreadsheet_handler'
require 'open_chain/custom_handler/ascena/ascena_ca_invoice_handler'
require 'open_chain/custom_handler/j_crew/j_crew_returns_parser'
require 'open_chain/custom_handler/pvh/pvh_shipment_workflow_parser'
require 'open_chain/custom_handler/advance/advance_parts_upload_parser'
require 'open_chain/custom_handler/advance/advance_po_origin_report_parser'
require 'open_chain/custom_handler/lumber_liquidators/lumber_product_upload_handler'
require 'open_chain/custom_handler/eddie_bauer/eddie_bauer_7501_handler'

class CustomFeaturesController < ApplicationController
  CSM_SYNC ||= 'OpenChain::CustomHandler::PoloCsmSyncHandler'
  ECELLERATE_SHIPMENT_ACTIVITY ||= 'OpenChain::CustomHandler::EcellerateShipmentActivityParser'
  EDDIE_CI_UPLOAD ||= 'OpenChain::CustomHandler::EddieBauer::EddieBauerFenixInvoiceHandler'
  FENIX_CI_UPLOAD ||= 'OpenChain::CustomHandler::FenixCommercialInvoiceSpreadsheetHandler'
  JCREW_PARTS ||= 'OpenChain::CustomHandler::JCrewPartsExtractParser'
  KEWILL_ISF ||= 'OpenChain::CustomHandler::KewillIsfManualParser'
  LENOX_SHIPMENT ||= 'OpenChain::CustomHandler::Lenox::LenoxShipmentStatusParser'
  POLO_CA_INVOICES ||= 'OpenChain::CustomHandler::Polo::PoloCaInvoiceHandler'
  POLO_SAP_BOM ||= 'OpenChain::CustomHandler::PoloSapBomHandler'
  UA_TBD_REPORT_PARSER ||= 'OpenChain::CustomHandler::UnderArmour::UaTbdReportParser'
  UA_STYLE_COLOR_REGION_PARSER ||= 'OpenChain::CustomHandler::UnderArmour::UaStyleColorRegionParser'
  UA_STYLE_COLOR_FACTORY_PARSER ||= 'OpenChain::CustomHandler::UnderArmour::UaStyleColorFactoryParser'
  LE_RETURNS_PARSER ||= 'OpenChain::CustomHandler::LandsEnd::LeReturnsParser'
  LE_CI_UPLOAD ||= 'OpenChain::CustomHandler::LandsEnd::LeReturnsCommercialInvoiceGenerator'
  ALLIANCE_DAY_END ||= 'OpenChain::CustomHandler::Intacct::AllianceDayEndHandler'
  CI_UPLOAD ||= 'OpenChain::CustomHandler::CiLoadHandler'
  LUMBER_EPD ||= 'OpenChain::CustomHandler::LumberLiquidators::LumberEpdParser'
  FISHER_CI_UPLOAD ||= 'OpenChain::CustomHandler::Fisher::FisherCommercialInvoiceSpreadsheetHandler'
  ASCENA_CA_INVOICES ||= 'OpenChain::CustomHandler::Ascena::AscenaCaInvoiceHandler'
  CREW_RETURNS ||= 'OpenChain::CustomHandler::JCrew::JCrewReturnsParser'
  PVH_WORKFLOW ||= 'OpenChain::CustomHandler::Pvh::PvhShipmentWorkflowParser'
  ADVAN_PART_UPLOAD ||= 'OpenChain::CustomHandler::Advance::AdvancePartsUploadParser'
  CQ_ORIGIN ||= 'OpenChain::CustomHandler::Advance::AdvancePoOriginReportParser'
  LUMBER_PART_UPLOAD ||= 'OpenChain::CustomHandler::LumberLiquidators::LumberProductUploadHandler'
  LUMBER_ORDER_CLOSER ||= 'OpenChain::CustomHandler::LumberLiquidators::LumberOrderCloser'
  EDDIE_7501_AUDIT ||= 'OpenChain::CustomHandler::EddieBauer::EddieBauer7501Handler'

  def index
    render :layout=>'one_col'
  end

  def lumber_epd_index
    generic_index OpenChain::CustomHandler::LumberLiquidators::LumberEpdParser, LUMBER_EPD, "EPD Report"
  end

  def lumber_epd_upload
    generic_upload LUMBER_EPD, "EPD Report", "lumber_epd"
  end

  def lumber_epd_download
    generic_download "EPD Report"
  end

  def ua_winshuttle_b_index
    generic_index OpenChain::CustomHandler::UnderArmour::UaWinshuttleScheduleBGenerator.new(nil), nil, "UA Winshuttle Reports", false
  end

  def ua_winshuttle_b_send
    action_secure(OpenChain::CustomHandler::UnderArmour::UaWinshuttleScheduleBGenerator.new.can_view?(current_user),Product,{:verb=>"view",:module_name=>"UA Winshuttle Reports",:lock_check=>false}) {
      eml = params[:email]
      if eml.blank?
        add_flash :errors, "You must specify an email address."
      else
        OpenChain::CustomHandler::UnderArmour::UaWinshuttleScheduleBGenerator.delay.run_and_email params[:email]
        add_flash :notices, "Your Winshuttle report is being generated and will be emailed to #{params[:email]}"
      end
      redirect_to '/custom_features/ua_winshuttle_b'
    }
  end

  def ua_winshuttle_index
    generic_index OpenChain::CustomHandler::UnderArmour::UaWinshuttleProductGenerator.new, nil, "UA Winshuttle Reports", false
  end

  def ua_winshuttle_send
    action_secure(OpenChain::CustomHandler::UnderArmour::UaWinshuttleProductGenerator.new.can_view?(current_user),Product,{:verb=>"view",:module_name=>"UA Winshuttle Reports",:lock_check=>false}) {
      eml = params[:email]
      if eml.blank?
        add_flash :errors, "You must specify an email address."
      else
        OpenChain::CustomHandler::UnderArmour::UaWinshuttleProductGenerator.delay.run_and_email params[:email]
        add_flash :notices, "Your Winshuttle report is being generated and will be emailed to #{params[:email]}"
      end
      redirect_to '/custom_features/ua_winshuttle'
    }
  end

  def ua_tbd_report_index
    generic_index OpenChain::CustomHandler::UnderArmour::UaTbdReportParser.new(nil), UA_TBD_REPORT_PARSER, "UA TBD Reports"
  end

  def ua_tbd_report_upload
    generic_upload UA_TBD_REPORT_PARSER, "UA TBD Reports", "ua_tbd"
  end

  def ua_tbd_report_download
    generic_download "UA TBD Reports"
  end

  def ua_style_color_region_index
    generic_index OpenChain::CustomHandler::UnderArmour::UaStyleColorRegionParser.new(nil), UA_STYLE_COLOR_REGION_PARSER, "UA Style/Color/Region"
  end

  def ua_style_color_region_upload
    generic_upload UA_STYLE_COLOR_REGION_PARSER, "UA Style/Color/Region", 'ua_style_color_region'
  end

  def ua_style_color_region_download
    generic_download "UA Style/Color/Region"
  end

  def ua_style_color_factory_index
    generic_index OpenChain::CustomHandler::UnderArmour::UaStyleColorFactoryParser.new(nil), UA_STYLE_COLOR_FACTORY_PARSER, "UA Style/Color/Factory"
  end

  def ua_style_color_factory_upload
    generic_upload UA_STYLE_COLOR_FACTORY_PARSER, "UA Style/Color/Factory", 'ua_style_color_factory'
  end

  def ua_style_color_factory_download
    generic_download "UA Style/Color/Region"
  end

  def kewill_isf_index
    generic_index OpenChain::CustomHandler::KewillIsfManualParser.new(nil), KEWILL_ISF, "Kewill ISF Manual Parser"
  end

  def kewill_isf_upload
    generic_upload KEWILL_ISF, "Kewill ISF Manual Parser", "kewill_isf"
  end

  def polo_sap_bom_index
    generic_index OpenChain::CustomHandler::PoloSapBomHandler.new(nil), POLO_SAP_BOM, "SAP Bill of Materials Files"
  end

  def polo_sap_bom_upload
    generic_upload POLO_SAP_BOM, "SAP Bill of Materials Files", "polo_sap_bom"
  end

  def polo_sap_bom_reprocess
    f = CustomFile.find params[:id]
    action_secure(OpenChain::CustomHandler::PoloSapBomHandler.new(f).can_view?(current_user),Product,{:verb=>'reprocess',:module_name=>"SAP Bill of Materials Files",:lock_check=>false}) {
      if f.start_at.blank? || f.start_at < 10.minutes.ago || f.error_message
        f.delay.process current_user
        add_flash :notices, "Your file is being processed.  You'll receive a system message when it's done."
      else
        add_flash :errors, "This file was last processed at #{f.start_at}.  You must wait 10 minutes to reprocess."
      end
      redirect_to '/custom_features/polo_sap_bom'
    }
  end

  def polo_sap_bom_download
    generic_download "SAP Bill of Materials Files"
  end

  def csm_sync_index
    generic_index OpenChain::CustomHandler::PoloCsmSyncHandler, CSM_SYNC, "CSM Sync Files"
  end

  def csm_sync_upload
    generic_upload CSM_SYNC, "CSM Sync Files", "csm_sync"
  end

  def csm_sync_reprocess
    f = CustomFile.find params[:id]
    action_secure(current_user.edit_products?,Product,{:verb=>"upload",:module_name=>"CSM Sync Files",:lock_check=>false}) {
      if f.start_at.blank? || f.start_at < 10.minutes.ago || f.error_message
        f.delay.process current_user
        add_flash :notices, "Your file is being processed.  You'll receive a system message when it's done."
      else
        add_flash :errors, "This file was last processed at #{f.start_at}.  You must wait 10 minutes to reprocess."
      end
      redirect_to '/custom_features/csm_sync'
    }
  end

  def csm_sync_download
    generic_download "CSM Sync Files"
  end

  def jcrew_parts_index
    generic_index OpenChain::CustomHandler::JCrewPartsExtractParser.new, JCREW_PARTS, "J Crew Parts Extract"
  end

  def jcrew_parts_upload
    generic_upload JCREW_PARTS, "J Crew Parts Extract", "jcrew_parts"
  end

  def jcrew_parts_download
    generic_download "J Crew Parts Extract"
  end

  def polo_ca_invoices_index
    generic_index OpenChain::CustomHandler::Polo::PoloCaInvoiceHandler.new(nil), POLO_CA_INVOICES, "Polo CA Invoices"
  end

  def polo_ca_invoices_upload
    generic_upload POLO_CA_INVOICES, "Polo CA Invoices", "polo_ca_invoices"
  end

  def polo_ca_invoices_download
    generic_download "Polo CA Invoices"
  end

  def ecellerate_shipment_activity_index
    generic_index OpenChain::CustomHandler::EcellerateShipmentActivityParser, ECELLERATE_SHIPMENT_ACTIVITY, "ECellerate Shipment Activity"
  end

  def ecellerate_shipment_activity_upload
    generic_upload ECELLERATE_SHIPMENT_ACTIVITY, "Fenix Commerical Invoice Upload", "ecellerate_shipment_activity"
  end

  def ecellerate_shipment_activity_download
    generic_download "Ecellerate Shipment Activity Upload"
  end

  def fenix_ci_load_index
    generic_index OpenChain::CustomHandler::FenixCommercialInvoiceSpreadsheetHandler.new(nil), FENIX_CI_UPLOAD, "Fenix Commerical Invoice Upload"
  end

  def fenix_ci_load_upload
    generic_upload FENIX_CI_UPLOAD, "Fenix Commerical Invoice Upload", "fenix_ci_load"
  end

  def fenix_ci_load_download
    generic_download "Fenix Commerical Invoice Upload"
  end

  def lenox_shipment_status_index
    generic_index OpenChain::CustomHandler::Lenox::LenoxShipmentStatusParser, LENOX_SHIPMENT, "Lenox OOCL Shipment Report Upload"
  end

  def lenox_shipment_status_upload
    generic_upload LENOX_SHIPMENT, "Lenox OOCL Shipment Report Upload", "lenox_shipment_status"
  end

  def lenox_shipment_status_download
    generic_download "Lenox OOCL Shipment Report Upload"
  end

  def eddie_fenix_ci_load_index
    generic_index OpenChain::CustomHandler::EddieBauer::EddieBauerFenixInvoiceHandler.new(nil), EDDIE_CI_UPLOAD, "Fenix Commerical Invoice Upload"
  end

  def eddie_fenix_ci_load_upload
    generic_upload EDDIE_CI_UPLOAD, "Eddie Bauer Fenix Commerical Invoice Upload", "eddie_fenix_ci_load"
  end

  def eddie_fenix_ci_load_download
    generic_download "Eddie Bauer Fenix Commerical Invoice Upload"
  end

  def le_returns_index
    generic_index OpenChain::CustomHandler::LandsEnd::LeReturnsParser.new(nil), LE_RETURNS_PARSER, "Lands' End Returns Upload"
  end

  def le_returns_upload
    generic_upload LE_RETURNS_PARSER, "Lands' End Returns Upload", "le_returns", flash_notice: "Your file is being processed.  You'll receive an email with a merged product worksheet when it's done."
  end

  def le_returns_download
    generic_download "Lands' End Returns Upload"
  end

  def le_ci_load_index
    generic_index OpenChain::CustomHandler::LandsEnd::LeReturnsCommercialInvoiceGenerator.new(nil), LE_CI_UPLOAD, "Lands' End Commerical Invoice Upload"
  end

  def le_ci_load_upload
    # Can't use generic since we're running this in a non-standard way
    if params[:file_number].blank?
      add_flash :errors, "You must enter a File Number."
      redirect_to '/custom_features/le_ci_load'
    else
      f = CustomFile.new(:file_type=>LE_CI_UPLOAD,:uploaded_by=>current_user,:attached=>params[:attached])
      action_secure(f.can_view?(current_user),f,{:verb=>"upload",:module_name=>"Lands' End Commerical Invoice Upload",:lock_check=>false}) {
        if params[:attached].nil?
          add_flash :errors, "You must select a file to upload."
        elsif f.save
          OpenChain::CustomHandler::LandsEnd::LeReturnsCommercialInvoiceGenerator.new(f).delay.generate_and_email current_user, params[:file_number]
          add_flash :notices, "Your file is being processed.  You'll receive an email with the CI Load file when it's done."
        else
          errors_to_flash f
        end
        redirect_to '/custom_features/le_ci_load'
      }
    end
  end

  def le_ci_load_download
    generic_download "Lands' End Commerical Invoice Upload"
  end

  def rl_fabric_parse_index
    generic_index OpenChain::CustomHandler::Polo::PoloFiberContentParser, nil, "MSL Fabric Analyzer", false
  end

  def rl_fabric_parse_run
    # Can't use generic, since we're not actually uploading a file here
    action_secure(OpenChain::CustomHandler::Polo::PoloFiberContentParser.can_view?(current_user),Product,{:verb=>"view",:module_name=>"MSL Fabric Analyzer",:lock_check=>false}) {
      styles = params[:styles]
      if styles.blank? || styles.split(/\s*\r?\n\s*/).size == 0
        add_flash :errors, "You must specify at least one style."
      else
        OpenChain::CustomHandler::Polo::PoloFiberContentParser.delay.update_styles params[:styles]
        add_flash :notices, "The styles you have entered will be analyzed shortly."
      end
      redirect_to '/custom_features/rl_fabric_parse'
    }
  end

  def alliance_day_end_index
    generic_index OpenChain::CustomHandler::Intacct::AllianceDayEndHandler, ALLIANCE_DAY_END, "Alliance Day End Processor"
  end

  def alliance_day_end_upload
    # Can't use the generic, we're loading two files and doing some other things here
    action_secure(OpenChain::CustomHandler::Intacct::AllianceDayEndHandler.can_view?(current_user),Entry,{:verb=>"view",:module_name=>"Alliance Day End Processor",:lock_check=>false}) {
      check_register = CustomFile.new(:file_type=>ALLIANCE_DAY_END,:uploaded_by=>current_user,:attached=>params[:check_register])
      invoice_file = CustomFile.new(:file_type=>ALLIANCE_DAY_END,:uploaded_by=>current_user,:attached=>params[:invoice_file])

      saved = false
      CustomFile.transaction do
        saved = check_register.save! && invoice_file.save!
      end

      if saved
        OpenChain::CustomHandler::Intacct::AllianceDayEndHandler.new(check_register, invoice_file).delay.process current_user
        add_flash :notices, "Your day end files are being processed.  You'll receive a system message "
      else
        errors_to_flash check_register
        errors_to_flash invoice_file
      end
      redirect_to '/custom_features/alliance_day_end'
    }
  end

  def alliance_day_end_download
    generic_download "Alliance Day End Processor"
  end

  def ci_load_index
    generic_index OpenChain::CustomHandler::CiLoadHandler, CI_UPLOAD, "CI Load Upload"
  end

  def ci_load_upload
    generic_upload CI_UPLOAD, "CI Load Upload", "ci_load"
  end

  def ci_load_download
    generic_download "CI Load Upload"
  end

  def fisher_ci_load_index
    generic_index OpenChain::CustomHandler::Fisher::FisherCommercialInvoiceSpreadsheetHandler.new(nil), FISHER_CI_UPLOAD, "Fisher CI Load Upload"
  end

  def fisher_ci_load_upload
    generic_upload(FISHER_CI_UPLOAD, "Fisher CI Load Upload", "fisher_ci_load", additional_process_params: {"invoice_date"=>params[:invoice_date]}) do |f|
      # Verify the invoice date was supplied
      invoice_date = Date.strptime(params[:invoice_date].to_s, "%Y-%m-%d") rescue nil

      if invoice_date.nil?
        add_flash :errors, "You must enter an Invoice Date."
      end
    end
  end

  def fisher_ci_load_download
    generic_download "Fisher CI Load Upload"
  end

  def ascena_ca_invoices_index
    generic_index OpenChain::CustomHandler::Ascena::AscenaCaInvoiceHandler.new(nil), ASCENA_CA_INVOICES, "Ascena CA Invoices"
  end

  def ascena_ca_invoices_upload
    generic_upload ASCENA_CA_INVOICES, "Ascena CA Invoices", "ascena_ca_invoices"
  end

  def ascena_ca_invoices_download
    generic_download "Ascena CA Invoices"
  end

  def crew_returns_index
    generic_index OpenChain::CustomHandler::JCrew::JCrewReturnsParser.new(nil), CREW_RETURNS, "J.Crew Returns"
  end

  def crew_returns_upload
    generic_upload CREW_RETURNS, "J.Crew Returns", "crew_returns"
  end

  def crew_returns_download
    generic_download "J.Crew Returns"
  end

  def pvh_workflow_index
    generic_index OpenChain::CustomHandler::Pvh::PvhShipmentWorkflowParser, PVH_WORKFLOW, "PVH Workflow"
  end

  def pvh_workflow_upload
    generic_upload PVH_WORKFLOW, "PVH Workflow", "pvh_workflow"
  end

  def pvh_workflow_download
    generic_download "PVH Workflow"
  end

  def advan_parts_index
    generic_index OpenChain::CustomHandler::Advance::AdvancePartsUploadParser, ADVAN_PART_UPLOAD, "Advance Parts"
  end

  def advan_parts_upload
    generic_upload ADVAN_PART_UPLOAD, "Advance Parts", "advan_parts"
  end

  def advan_parts_download
    generic_download "Advance Parts"
  end

  def cq_origin_index
    generic_index OpenChain::CustomHandler::Advance::AdvancePoOriginReportParser, CQ_ORIGIN, "Carquest Orders"
  end

  def cq_origin_upload
    generic_upload(CQ_ORIGIN, "Carquest Orders", "cq_origin") do |f|
      if !f.attached_file_name.blank? && !OpenChain::CustomHandler::Advance::AdvancePoOriginReportParser.new(f).valid_file?
        add_flash :errors, "You must upload a valid Excel file."
      end
    end
  end

  def cq_origin_download
    generic_download "Carquest Orders"
  end

  def lumber_part_index
    generic_index OpenChain::CustomHandler::LumberLiquidators::LumberProductUploadHandler, LUMBER_PART_UPLOAD, "Lumber Product Upload"
  end

  def lumber_part_upload
    generic_upload(LUMBER_PART_UPLOAD, "Lumber Product Upload", "lumber_part") do |f|
      if !f.attached_file_name.blank? && !OpenChain::CustomHandler::LumberLiquidators::LumberProductUploadHandler.valid_file?(f.attached_file_name)
        add_flash :errors, "You must upload a valid Excel file or csv file."
      end
    end
  end

  def lumber_part_download
    generic_download "Lumber Product Upload"
  end

  def lumber_order_close_index
    generic_index OpenChain::CustomHandler::LumberLiquidators::LumberOrderCloser, LUMBER_ORDER_CLOSER, "Lumber Order Close"
  end

  def lumber_order_close
    k = OpenChain::CustomHandler::LumberLiquidators::LumberOrderCloser
    action_secure(k.can_view?(current_user),nil,{:verb=>"close", :module_name=>"Orders", :lock_check=> false}) {
      orders = params[:orders]
      if orders.blank?
        error_redirect "You must include at least one order."
        return
      end
      key = "#{MasterSetup.get.uuid}/lumber_order_closer/#{Time.now.to_i}.txt"
      OpenChain::S3.upload_data(OpenChain::S3.bucket_name,key,orders)
      k.delay.process(key,current_user.id)
      add_flash :notices, "Your data is being processed. You will receive a system message when it is complete."
      redirect_to
    }
  end

  def eddie_bauer_7501_index
    generic_index OpenChain::CustomHandler::EddieBauer::EddieBauer7501Handler.new(nil), EDDIE_7501_AUDIT, "Eddie Bauer 7501 Audit"
  end

  def eddie_bauer_7501_upload
    generic_upload EDDIE_7501_AUDIT, "Eddie Bauer 7501 Audit", "eddie_bauer_7501", flash_notice: "Your file is being processed.  You'll receive an email when it completes."
  end

  def eddie_bauer_7501_download
    generic_download "Eddie Bauer 7501 Audit"
  end

  private
    def generic_download mod_name
      f = CustomFile.find params[:id]
      action_secure(f.can_view?(current_user),f,{:verb=>"download",:module_name=>mod_name,:lock_check=>false}) {
        redirect_to f.secure_url
      }
    end

    def generic_index klass, class_name, mod_name, show_file_list = true
      action_secure(klass.can_view?(current_user),nil,{:verb=>"view",:module_name=>mod_name,:lock_check=>false}) {
        if show_file_list
          @files = CustomFile.where(:file_type=>class_name).order('created_at DESC').paginate(:per_page=>20,:page=>params[:page])
        end
      }
    end

    def generic_upload class_name, mod_name, custom_feature_path, additional_process_params: {}, flash_notice: "Your file is being processed.  You'll receive a VFI Track message when it completes."
      f = CustomFile.new(:file_type=>class_name,:uploaded_by=>current_user,:attached=>params[:attached])
      action_secure(f.can_view?(current_user),f,{:verb=>"upload",:module_name=>mod_name,:lock_check=>false}) {

        if params[:attached].nil?
          add_flash :errors, "You must select a file to upload."
        end

        # Give way for caller to execute extra validations, if you wish to stop the execution of the file
        # you should add flash errors in the block you pass to this method
        if block_given?
          yield f
        end

        if !has_errors? && f.save
          CustomFile.delay.process f.id, current_user.id, additional_process_params
          add_flash :notices, flash_notice
        else
          errors_to_flash f
        end
        redirect_to "/custom_features/#{custom_feature_path}"
      }
    end
end
