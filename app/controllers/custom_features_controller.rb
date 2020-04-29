require 'open_chain/s3'
require 'open_chain/custom_handler/ci_load_handler'
require 'open_chain/custom_handler/ecellerate_shipment_activity_parser'
require 'open_chain/custom_handler/eddie_bauer/eddie_bauer_fenix_invoice_handler'
require 'open_chain/custom_handler/fenix_commercial_invoice_spreadsheet_handler'
require 'open_chain/custom_handler/intacct/alliance_day_end_handler'
require 'open_chain/custom_handler/j_crew_parts_extract_parser'
require 'open_chain/custom_handler/lands_end/le_returns_parser'
require 'open_chain/custom_handler/lands_end/le_returns_commercial_invoice_generator'
require 'open_chain/custom_handler/lenox/lenox_shipment_status_parser'
require 'open_chain/custom_handler/lumber_liquidators/lumber_allport_billing_file_parser'
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
require 'open_chain/custom_handler/under_armour/under_armour_missing_classifications_upload_parser'
require 'open_chain/custom_handler/fisher/fisher_commercial_invoice_spreadsheet_handler'
require 'open_chain/custom_handler/ascena/ascena_ca_invoice_handler'
require 'open_chain/custom_handler/j_crew/j_crew_returns_parser'
require 'open_chain/custom_handler/pvh/pvh_shipment_workflow_parser'
require 'open_chain/custom_handler/advance/advance_parts_upload_parser'
require 'open_chain/custom_handler/advance/advance_po_origin_report_parser'
require 'open_chain/custom_handler/lumber_liquidators/lumber_product_upload_handler'
require 'open_chain/custom_handler/eddie_bauer/eddie_bauer_7501_handler'
require 'open_chain/custom_handler/hm/hm_po_line_parser'
require 'open_chain/custom_handler/hm/hm_product_xref_parser'
require 'open_chain/custom_handler/hm/hm_receipt_file_parser'
require 'open_chain/custom_handler/ascena/ascena_product_upload_parser'
require 'open_chain/custom_handler/pvh/pvh_ca_workflow_parser'
require 'open_chain/custom_handler/under_armour/ua_sites_subs_product_generator'
require 'open_chain/custom_handler/generic/isf_late_flag_file_parser'
require 'open_chain/custom_handler/vandegrift/vandegrift_intacct_invoice_report_handler'
require 'open_chain/custom_handler/lands_end/le_chapter_98_parser'
require 'open_chain/custom_handler/customer_invoice_handler'
require 'open_chain/custom_handler/lumber_liquidators/lumber_product_vendor_patent_statement_uploader'
require 'open_chain/custom_handler/lumber_liquidators/lumber_product_vendor_carb_statement_uploader'
require 'open_chain/custom_handler/kirklands/kirklands_product_upload_parser'
require 'open_chain/custom_handler/lands_end/le_product_parser'
require 'open_chain/custom_handler/burlington/burlington_product_parser'

class CustomFeaturesController < ApplicationController
  CSM_SYNC ||= 'OpenChain::CustomHandler::PoloCsmSyncHandler'
  ECELLERATE_SHIPMENT_ACTIVITY ||= 'OpenChain::CustomHandler::EcellerateShipmentActivityParser'
  EDDIE_CI_UPLOAD ||= 'OpenChain::CustomHandler::EddieBauer::EddieBauerFenixInvoiceHandler'
  FENIX_CI_UPLOAD ||= 'OpenChain::CustomHandler::FenixCommercialInvoiceSpreadsheetHandler'
  JCREW_PARTS ||= 'OpenChain::CustomHandler::JCrewPartsExtractParser'
  LENOX_SHIPMENT ||= 'OpenChain::CustomHandler::Lenox::LenoxShipmentStatusParser'
  POLO_CA_INVOICES ||= 'OpenChain::CustomHandler::Polo::PoloCaInvoiceHandler'
  POLO_SAP_BOM ||= 'OpenChain::CustomHandler::PoloSapBomHandler'
  UA_TBD_REPORT_PARSER ||= 'OpenChain::CustomHandler::UnderArmour::UaTbdReportParser'
  UA_STYLE_COLOR_REGION_PARSER ||= 'OpenChain::CustomHandler::UnderArmour::UaStyleColorRegionParser'
  UA_STYLE_COLOR_FACTORY_PARSER ||= 'OpenChain::CustomHandler::UnderArmour::UaStyleColorFactoryParser'
  UA_MISSING_CLASSIFICATIONS_PARSER ||= 'OpenChain::CustomHandler::UnderArmour::UnderArmourMissingClassificationsUploadParser'
  UA_SITES_SUBS ||= 'OpenChain::CustomHandler::UnderArmour::UaSitesSubsProductGenerator'
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
  HM_PO_LINE_PARSER ||= 'OpenChain::CustomHandler::Hm::HmPoLineParser'
  ASCENA_PARTS_PARSER ||= 'OpenChain::CustomHandler::Ascena::AscenaProductUploadParser'
  PVH_CA_WORKFLOW ||= 'OpenChain::CustomHandler::Pvh::PvhCaWorkflowParser'
  ISF_LATE_FLAG_FILE_PARSER ||= 'OpenChain::CustomHandler::Generic::IsfLateFlagFileParser'
  INTACCT_INVOICE_REPORT ||= 'OpenChain::CustomHandler::Vandegrift::VandegriftIntacctInvoiceReportHandler'
  LUMBER_ALLPORT_BILLING_FILE_PARSER ||= 'OpenChain::CustomHandler::LumberLiquidators::LumberAllportBillingFileParser'
  LE_CHAPTER_98_PARSER ||= 'OpenChain::CustomHandler::LandsEnd::LeChapter98Parser'
  CUSTOMER_INVOICE_HANDLER ||= 'OpenChain::CustomHandler::CustomerInvoiceHandler'
  HM_PRODUCT_XREF_PARSER ||= 'OpenChain::CustomHandler::Hm::HmProductXrefParser'
  HM_RECEIPT_FILE_PARSER ||= 'OpenChain::CustomHandler::Hm::HmReceiptFileParser'
  LL_CARB_UPLOAD ||= 'OpenChain::CustomHandler::LumberLiquidators::LumberProductVendorCarbStatementUploader'
  LL_PATENT_UPLOAD ||= 'OpenChain::CustomHandler::LumberLiquidators::LumberProductVendorPatentStatementUploader'
  KIRKLANDS_PRODUCT ||= 'OpenChain::CustomHandler::Kirklands::KirklandsProductUploadParser'
  LE_PRODUCT ||= 'OpenChain::CustomHandler::LandsEnd::LeProductParser'
  BURLINGTON_PRODUCT ||= 'OpenChain::CustomHandler::Burlington::BurlingtonProductParser'

  SEARCH_PARAMS = {
    'filename' => {:field => 'attached_file_name', :label => 'Filename'},
    'uploaded_by' => {:field => 'CONCAT(users.first_name, " ", users.last_name)', :label => 'Uploaded By'},
    'uploaded_at' => {:field => 'custom_files.created_at', :label => 'Uploaded At'},
    'start' => {:field => 'start_at', :label => 'Start'},
    'finish' => {:field => 'finish_at', :label => 'Finish'}
  }
  def set_page_title
    @page_title ||= 'Custom Feature'
  end

  def index
    @no_action_bar = true # Not in use so free up some space
    render :layout=>'one_col'
  end

  def le_chapter_98_index
    generic_index OpenChain::CustomHandler::LandsEnd::LeChapter98Parser.new(nil), LE_CHAPTER_98_PARSER, "Land's End Chapter 98 Parser"
  end

  def le_chapter_98_download
    generic_download "Lands' End Chapter 98 Return Files"
  end

  def le_chapter_98_upload
    generic_upload(LE_CHAPTER_98_PARSER, "Lands' End Chapter 98 Return Upload", "le_chapter_98_load", additional_process_params: {"file_number"=>params[:file_number]}) do
      file_number = params[:file_number]

      if file_number.nil?
        add_flash :errors, "You must enter a file number"
      end
    end
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
    generic_index OpenChain::CustomHandler::UnderArmour::UaWinshuttleScheduleBGenerator.new, nil, "UA Winshuttle Reports", false
  end

  def ua_winshuttle_b_send
    action_secure(OpenChain::CustomHandler::UnderArmour::UaWinshuttleScheduleBGenerator.new.can_view?(current_user), Product, {:verb=>"view", :module_name=>"UA Winshuttle Reports", :lock_check=>false}) {
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
    action_secure(OpenChain::CustomHandler::UnderArmour::UaWinshuttleProductGenerator.new.can_view?(current_user), Product, {:verb=>"view", :module_name=>"UA Winshuttle Reports", :lock_check=>false}) {
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

  def ua_sites_subs_index
    generic_index OpenChain::CustomHandler::UnderArmour::UaSitesSubsProductGenerator, nil, "UA Sites & Subs Reports", false
  end

  def ua_sites_subs_send
    action_secure(OpenChain::CustomHandler::UnderArmour::UaSitesSubsProductGenerator.can_view?(current_user), Product, {:verb=>"view", :module_name=>"UA Sites & Subs Reports", :lock_check=>false}) {
      eml = params[:email]
      if eml.blank?
        add_flash :errors, "You must specify an email address."
      else
        OpenChain::CustomHandler::UnderArmour::UaSitesSubsProductGenerator.delay.run_and_email current_user, params[:email]
        add_flash :notices, "Your Sites & Subs report is being generated and will be emailed to #{params[:email]}"
      end
      redirect_to '/custom_features/ua_sites_subs'
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

  def ua_missing_classifications_index
    generic_index OpenChain::CustomHandler::UnderArmour::UnderArmourMissingClassificationsUploadParser.new(nil), UA_MISSING_CLASSIFICATIONS_PARSER, 'UA Missing Classifications'
  end

  def ua_missing_classifications_upload
    generic_upload(UA_MISSING_CLASSIFICATIONS_PARSER, 'UA Missing Classifications', 'ua_missing_classifications') do |f|
      if !f.attached_file_name.blank? && !OpenChain::CustomHandler::UnderArmour::UnderArmourMissingClassificationsUploadParser.valid_file?(f.attached_file_name)
        add_flash :errors, "You must upload a valid Excel file or csv file."
      end
    end
  end

  def ua_missing_classifications_download
    generic_download 'UA Missing Classifications'
  end

  def polo_sap_bom_index
    generic_index OpenChain::CustomHandler::PoloSapBomHandler.new(nil), POLO_SAP_BOM, "SAP Bill of Materials Files"
  end

  def polo_sap_bom_upload
    generic_upload POLO_SAP_BOM, "SAP Bill of Materials Files", "polo_sap_bom"
  end

  def polo_sap_bom_reprocess
    f = CustomFile.find params[:id]
    action_secure(OpenChain::CustomHandler::PoloSapBomHandler.new(f).can_view?(current_user), Product, {:verb=>'reprocess', :module_name=>"SAP Bill of Materials Files", :lock_check=>false}) {
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
    action_secure(current_user.edit_products?, Product, {:verb=>"upload", :module_name=>"CSM Sync Files", :lock_check=>false}) {
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
    additional_params = {file_number: params[:file_number]}
    generic_upload(LE_CI_UPLOAD, "Lands' End Commerical Invoice Upload", "le_ci_load", additional_process_params: additional_params,  flash_notice: "Your file is being processed.  You'll receive an email with the CI Load file when it's done.") do |f|
      if additional_params[:file_number].blank?
        add_flash :errors, "You must enter a File Number."
      end
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
    action_secure(OpenChain::CustomHandler::Polo::PoloFiberContentParser.can_view?(current_user), Product, {:verb=>"view", :module_name=>"MSL Fabric Analyzer", :lock_check=>false}) {
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
    action_secure(OpenChain::CustomHandler::Intacct::AllianceDayEndHandler.can_view?(current_user), Entry, {:verb=>"view", :module_name=>"Alliance Day End Processor", :lock_check=>false}) {
      check_register = CustomFile.new(:file_type=>ALLIANCE_DAY_END, :uploaded_by=>current_user, :attached=>params[:check_register])
      invoice_file = CustomFile.new(:file_type=>ALLIANCE_DAY_END, :uploaded_by=>current_user, :attached=>params[:invoice_file])

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
    generic_upload(CI_UPLOAD, "CI Load Upload", "ci_load") do |f|
      if !f.attached_file_name.blank? && !OpenChain::CustomHandler::CiLoadHandler.valid_file?(f.attached_file_name)
        add_flash :errors, "You must upload a valid Excel (xls or xlsx) file or csv file."
      end
    end
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

  def pvh_ca_workflow_index
    generic_index OpenChain::CustomHandler::Pvh::PvhCaWorkflowParser, PVH_CA_WORKFLOW, "PVH CA Workflow Parser"
  end

  def pvh_ca_workflow_upload
    generic_upload PVH_CA_WORKFLOW, "PVH CA Workflow Parser", "pvh_ca_workflow"
  end

  def pvh_ca_workflow_download
    generic_download "PVH CA Workflow Parser"
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
    action_secure(k.can_view?(current_user), nil, {:verb=>"close", :module_name=>"Orders", :lock_check=> false}) {
      orders = params[:orders]
      effective_date = params[:effective_date]
      if effective_date.blank?
        error_redirect "You must enter an effective date."
        return
      elsif orders.blank?
        error_redirect "You must include at least one order."
        return
      end
      key = "#{MasterSetup.get.uuid}/lumber_order_closer/#{Time.now.to_i}.txt"
      OpenChain::S3.upload_data(OpenChain::S3.bucket_name, key, orders)
      k.delay.process(key, effective_date, current_user.id)
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

  def hm_po_line_parser_index
    generic_index OpenChain::CustomHandler::Hm::HmPoLineParser.new(nil), HM_PO_LINE_PARSER, "H&M PO Lines"
  end

  def hm_po_line_parser_upload
    generic_upload HM_PO_LINE_PARSER, "H&M PO Lines", "hm_po_line_parser"
  end

  def hm_po_line_parser_download
    generic_download "H&M PO Lines"
  end

  def ascena_product_index
    generic_index OpenChain::CustomHandler::Ascena::AscenaProductUploadParser.new(nil), ASCENA_PARTS_PARSER, "Ascena Product Upload"
  end

  def ascena_product_upload
    generic_upload ASCENA_PARTS_PARSER, "Ascena Product Upload", "ascena_product"
  end

  def ascena_product_download
    generic_download "Ascena Product Upload"
  end

  def isf_late_filing_index
    generic_index OpenChain::CustomHandler::Generic::IsfLateFlagFileParser.new(nil), ISF_LATE_FLAG_FILE_PARSER, 'ISF Late Filing Reports'
  end

  def isf_late_filing_upload
    generic_upload(ISF_LATE_FLAG_FILE_PARSER, 'ISF Late Filing Reports', 'isf_late_filing') do |f|
      if !f.attached_file_name.blank? && !OpenChain::CustomHandler::Generic::IsfLateFlagFileParser.valid_file?(f.attached_file_name)
        add_flash :errors, "You must upload a valid Excel file or csv file."
      end
    end
  end

  def isf_late_filing_download
    generic_download 'ISF Late Filing Reports'
  end

  def intacct_invoice_index
    generic_index INTACCT_INVOICE_REPORT.constantize, INTACCT_INVOICE_REPORT, 'Intacct Invoice Report'
  end

  def intacct_invoice_upload
    generic_upload(INTACCT_INVOICE_REPORT, 'Intacct Invoice Report', 'intacct_invoice', flash_notice: "Your file is being processed.  You'll receive an email when it completes.") do |f|
      if !f.attached_file_name.blank? && !OpenChain::CustomHandler::Vandegrift::VandegriftIntacctInvoiceReportHandler.valid_file?(f.attached_file_name)
        add_flash :errors, "You must upload a valid Excel file."
      end
    end
  end

  def intacct_invoice_download
    generic_download 'Intacct Invoice Report'
  end

  def lumber_allport_billing_index
    generic_index OpenChain::CustomHandler::LumberLiquidators::LumberAllportBillingFileParser.new(nil), LUMBER_ALLPORT_BILLING_FILE_PARSER, 'Lumber ACS Billing Validation'
  end

  def lumber_allport_billing_upload
    generic_upload(LUMBER_ALLPORT_BILLING_FILE_PARSER, 'Lumber ACS Billing Validation', 'lumber_allport_billing') do |f|
      if !f.attached_file_name.blank? && !OpenChain::CustomHandler::LumberLiquidators::LumberAllportBillingFileParser.valid_file?(f.attached_file_name)
        add_flash :errors, "You must upload a valid Excel file."
      end
    end
  end

  def lumber_allport_billing_download
    generic_download 'Lumber ACS Billing Validation'
  end

  def customer_invoice_index
    importers = Company.where("system_code IS NOT NULL and system_code <> ''")
                       .active_importers.order(:name)
                       .map {|c| ["#{c.name} (#{c.system_code})", c.system_code] }
    generic_index CUSTOMER_INVOICE_HANDLER.constantize, CUSTOMER_INVOICE_HANDLER, 'Customer Invoice (810) Upload', true, {importers: importers}
  end

  def customer_invoice_upload
    generic_upload(CUSTOMER_INVOICE_HANDLER, 'Customer Invoice Uploader', 'customer_invoice_handler', additional_process_params: params) do |f|
      if !f.attached_file_name.blank? && !CUSTOMER_INVOICE_HANDLER.constantize.valid_file?(f.attached_file_name)
        add_flash :errors, "You must upload a valid Excel or CSV file."
      end
      if params['cust_num'].blank?
        add_flash :errors, "Please select an importer."
      end
    end
  end

  def customer_invoice_download
    generic_download 'Customer Invoice Upload (810)'
  end

  def hm_product_xref_index
    generic_index OpenChain::CustomHandler::Hm::HmProductXrefParser.new(nil), HM_PRODUCT_XREF_PARSER, 'H&M Product Cross Reference'
  end

  def hm_product_xref_upload
    generic_upload(HM_PRODUCT_XREF_PARSER, 'H&M Product Cross Reference', 'hm_product_xref') do |f|
      if !f.attached_file_name.blank? && !OpenChain::CustomHandler::Hm::HmProductXrefParser.valid_file?(f.attached_file_name)
        add_flash :errors, "You must upload a valid Excel file or csv file."
      end
    end
  end

  def hm_product_xref_download
    generic_download 'H&M Product Cross Reference'
  end

  def hm_receipt_file_index
    generic_index OpenChain::CustomHandler::Hm::HmReceiptFileParser.new(nil), HM_RECEIPT_FILE_PARSER, 'H&M Receipt File'
  end

  def hm_receipt_file_upload
    generic_upload(HM_RECEIPT_FILE_PARSER, 'H&M Receipt File', 'hm_receipt_file') do |f|
      if !f.attached_file_name.blank? && !OpenChain::CustomHandler::Hm::HmReceiptFileParser.valid_file?(f.attached_file_name)
        add_flash :errors, "You must upload a valid Excel file or csv file."
      end
    end
  end

  def hm_receipt_file_download
    generic_download 'H&M Receipt File'
  end

  def lumber_carb_index
    generic_index LL_CARB_UPLOAD.constantize, LL_CARB_UPLOAD, 'Vendor CARB Statement Upload', true
  end

  def lumber_carb_upload
    generic_upload(LL_CARB_UPLOAD, 'Vendor CARB Statement Upload', 'lumber_carb', additional_process_params: params) do |f|
      if !f.attached_file_name.blank? && !LL_CARB_UPLOAD.constantize.valid_file?(f.attached_file_name)
        add_flash :errors, "You must upload a valid Excel or CSV file."
      end
    end
  end

  def lumber_carb_download
    generic_download 'Vendor CARB Statement Upload'
  end

  def lumber_patent_index
    generic_index LL_PATENT_UPLOAD.constantize, LL_PATENT_UPLOAD, 'Vendor Patent Statement Upload', true
  end

  def lumber_patent_upload
    generic_upload(LL_PATENT_UPLOAD, 'Vendor Patent Statement Upload', 'lumber_patent', additional_process_params: params) do |f|
      if !f.attached_file_name.blank? && !LL_PATENT_UPLOAD.constantize.valid_file?(f.attached_file_name)
        add_flash :errors, "You must upload a valid Excel or CSV file."
      end
    end
  end

  def lumber_patent_download
    generic_download 'Vendor Patent Statement Upload'
  end

  def kirklands_product_index
    generic_index OpenChain::CustomHandler::Kirklands::KirklandsProductUploadParser, KIRKLANDS_PRODUCT, "Kirklands Products"
  end

  def kirklands_product_upload
    generic_upload(KIRKLANDS_PRODUCT, "Kirklands Product", "kirklands_product") do |f|
      if !f.attached_file_name.blank? && !OpenChain::CustomHandler::Kirklands::KirklandsProductUploadParser.valid_file?(f.attached_file_name)
        add_flash :errors, "You must upload a valid Excel file or csv file."
      end
    end
  end

  def kirklands_product_download
    generic_download "Kirklands Products"
  end

  def burlington_product_index
    generic_index OpenChain::CustomHandler::Burlington::BurlingtonProductParser, BURLINGTON_PRODUCT, "Burlington Products"
  end

  def burlington_product_upload
    generic_upload(BURLINGTON_PRODUCT, "Burlington Products", "burlington_product") do |f|
      if !f.attached_file_name.blank? && !BURLINGTON_PRODUCT.constantize.valid_file?(f.attached_file_name)
        add_flash :errors, "You must upload a valid Excel file or csv file."
      end
    end
  end

  def burlington_product_download
    generic_download "Burlington Products"
  end

  def le_product_index
    generic_index OpenChain::CustomHandler::LandsEnd::LeProductParser, LE_PRODUCT, "Lands' End Products"
  end

  def le_product_upload
    generic_upload(LE_PRODUCT, "Lands' End Products", "le_product") do |f|
      if !f.attached_file_name.blank? && !LE_PRODUCT.constantize.valid_file?(f.attached_file_name)
        add_flash :errors, "You must upload a valid Excel file or csv file."
      end
    end
  end

  def le_product_download
    generic_download "Lands' End Products"
  end

  private
    def generic_download mod_name
      f = CustomFile.find params[:id]
      action_secure(f.can_view?(current_user), f, {:verb=>"download", :module_name=>mod_name, :lock_check=>false}) {
        redirect_to f.secure_url
      }
    end

    def generic_index klass, class_name, mod_name, show_file_list = true, additional_vars={}
      action_secure(klass.can_view?(current_user), nil, {:verb=>"view", :module_name=>mod_name, :lock_check=>false}) {
        if show_file_list
          @secured = CustomFile.where(file_type: class_name)
          sp = SEARCH_PARAMS.clone
          s = build_search(sp, 'filename', 'start', 'd')
          s = s.joins("INNER JOIN users ON users.id = custom_files.uploaded_by_id")
          if params[:f1].blank?
            s = s.order('custom_files.created_at DESC')
          end
          @files = s.paginate(:per_page=>20, :page=>params[:page])
          @files
          @vars = additional_vars
        end
      }
    end

    def generic_upload class_name, mod_name, custom_feature_path, additional_process_params: {}, flash_notice: "Your file is being processed.  You'll receive a " + MasterSetup.application_name + " message when it completes."
      f = CustomFile.new(:file_type=>class_name, :uploaded_by=>current_user, :attached=>params[:attached])
      action_secure(f.can_view?(current_user), f, {:verb=>"upload", :module_name=>mod_name, :lock_check=>false}) {

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

    def secure
      @secured
    end
end
