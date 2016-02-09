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
require 'open_chain/custom_handler/polo_ca_entry_parser'
require 'open_chain/custom_handler/polo_csm_sync_handler'
require 'open_chain/custom_handler/polo/polo_ca_invoice_handler'
require 'open_chain/custom_handler/polo/polo_fiber_content_parser'
require 'open_chain/custom_handler/polo_sap_bom_handler'
require 'open_chain/custom_handler/under_armour/ua_tbd_report_parser'
require 'open_chain/custom_handler/under_armour/ua_winshuttle_product_generator'
require 'open_chain/custom_handler/under_armour/ua_winshuttle_schedule_b_generator'
require 'open_chain/custom_handler/fisher/fisher_commercial_invoice_spreadsheet_handler'
require 'open_chain/custom_handler/ascena_ca_invoice_handler'
require 'open_chain/custom_handler/j_crew/j_crew_returns_parser'
require 'open_chain/custom_handler/pvh/pvh_shipment_workflow_parser'

class CustomFeaturesController < ApplicationController
  CA_EFOCUS = 'OpenChain::CustomHandler::PoloCaEntryParser'
  CSM_SYNC = 'OpenChain::CustomHandler::PoloCsmSyncHandler'
  ECELLERATE_SHIPMENT_ACTIVITY = 'OpenChain::CustomHandler::EcellerateShipmentActivityParser'
  EDDIE_CI_UPLOAD = 'OpenChain::CustomHandler::EddieBauer::EddieBauerFenixInvoiceHandler'
  FENIX_CI_UPLOAD = 'OpenChain::CustomHandler::FenixCommercialInvoiceSpreadsheetHandler'
  JCREW_PARTS = 'OpenChain::CustomHandler::JCrewPartsExtractParser'
  KEWILL_ISF = 'OpenChain::CustomHandler::KewillIsfManualParser'
  LENOX_SHIPMENT = 'OpenChain::CustomHandler::Lenox::LenoxShipmentStatusParser'
  POLO_CA_INVOICES = 'OpenChain::CustomHandler::Polo::PoloCaInvoiceHandler'
  POLO_SAP_BOM = 'OpenChain::CustomHandler::PoloSapBomHandler'
  UA_TBD_REPORT_PARSER = 'OpenChain::CustomHandler::UnderArmour::UaTbdReportParser'
  LE_RETURNS_PARSER = 'OpenChain::CustomHandler::LandsEnd::LeReturnsParser'
  LE_CI_UPLOAD = 'OpenChain::CustomHandler::LandsEnd::LeReturnsCommercialInvoiceGenerator'
  ALLIANCE_DAY_END = 'OpenChain::CustomHandler::Intacct::AllianceDayEndHandler'
  CI_UPLOAD = 'OpenChain::CustomHandler::CiLoadHandler'
  LUMBER_EPD = 'OpenChain::CustomHandler::LumberLiquidators::LumberEpdParser'
  FISHER_CI_UPLOAD = 'OpenChain::CustomHandler::Fisher::FisherCommercialInvoiceSpreadsheetHandler'
  ASCENA_CA_INVOICES = 'OpenChain::CustomHandler::AscenaCaInvoiceHandler'
  CREW_RETURNS ||= 'OpenChain::CustomHandler::JCrew::JCrewReturnsParser'
  PVH_WORKFLOW ||= 'OpenChain::CustomHandler::Pvh::PvhShipmentWorkflowParser'

  def index
    render :layout=>'one_col'
  end

  def lumber_epd_index
    action_secure(OpenChain::CustomHandler::LumberLiquidators::LumberEpdParser.can_view?(current_user),Product,{:verb=>"view",:module_name=>"EPD Report",:lock_check=>false}) {
      @files = CustomFile.where(:file_type=>LUMBER_EPD).order('created_at DESC').paginate(:per_page=>20,:page=>params[:page])
      render :layout => 'one_col'
    }
  end
  def lumber_epd_upload
    f = CustomFile.new(:file_type=>LUMBER_EPD,:uploaded_by=>current_user,:attached=>params[:attached])
    action_secure(OpenChain::CustomHandler::LumberLiquidators::LumberEpdParser.can_view?(current_user),Entry,{:verb=>"view",:module_name=>"EPD Report",:lock_check=>false}) {
      if params[:attached].nil?
        add_flash :errors, "You must select a file to upload." 
      elsif f.save
        f.delay.process(current_user)
        add_flash :notices, "Your file is being processed.  You'll receive a system message when it's done."
      else
        errors_to_flash f
      end
      redirect_to '/custom_features/lumber_epd'
    }
  end
  def lumber_epd_download
    f = CustomFile.find params[:id] 
    action_secure(OpenChain::CustomHandler::LumberLiquidators::LumberEpdParser.can_view?(current_user),Entry,{:verb=>"view",:module_name=>"EPD Report",:lock_check=>false}) {
      redirect_to f.secure_url
    }
  end
  def ua_winshuttle_b_index
    action_secure(OpenChain::CustomHandler::UnderArmour::UaWinshuttleScheduleBGenerator.new.can_view?(current_user),Product,{:verb=>"view",:module_name=>"UA Winshuttle Reports",:lock_check=>false}) {
      #nothing to do here
    }
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
    action_secure(OpenChain::CustomHandler::UnderArmour::UaWinshuttleProductGenerator.new.can_view?(current_user),Product,{:verb=>"view",:module_name=>"UA Winshuttle Reports",:lock_check=>false}) {
      #nothing to do here
    }
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
    action_secure(OpenChain::CustomHandler::UnderArmour::UaTbdReportParser.new(nil).can_view?(current_user),Entry,{:verb=>"view",:module_name=>"UA TBD Reports",:lock_check=>false}) {
      @files = CustomFile.where(:file_type=>UA_TBD_REPORT_PARSER).order('created_at DESC').paginate(:per_page=>20,:page=>params[:page])
      render :layout => 'one_col'
    }
  end
  def ua_tbd_report_upload
    f = CustomFile.new(:file_type=>UA_TBD_REPORT_PARSER,:uploaded_by=>current_user,:attached=>params[:attached])
    action_secure(OpenChain::CustomHandler::UnderArmour::UaTbdReportParser.new(f).can_view?(current_user),Entry,{:verb=>"view",:module_name=>"UA TBD Reports",:lock_check=>false}) {
      if params[:attached].nil?
        add_flash :errors, "You must select a file to upload." 
      elsif f.save
        f.delay.process(current_user)
        add_flash :notices, "Your file is being processed.  You'll receive a system message when it's done."
      else
        errors_to_flash f
      end
      redirect_to '/custom_features/ua_tbd'
    }
  end
  def ua_tbd_report_download
    f = CustomFile.find params[:id] 
    action_secure(OpenChain::CustomHandler::UnderArmour::UaTbdReportParser.new(f).can_view?(current_user),Entry,{:verb=>"view",:module_name=>"UA TBD Reports",:lock_check=>false}) {
      redirect_to f.secure_url
    }
  end
  def polo_efocus_index
    action_secure(OpenChain::CustomHandler::PoloCaEntryParser.new(nil).can_view?(current_user),Entry,{:verb=>"view",:module_name=>"Polo Canada Entry Worksheets",:lock_check=>false}) {
      @files = CustomFile.where(:file_type=>CA_EFOCUS).order('created_at DESC').paginate(:per_page=>20,:page=>params[:page])
      render :layout => 'one_col'
    }
  end
  def polo_efocus_upload
    f = CustomFile.new(:file_type=>CA_EFOCUS,:uploaded_by=>current_user,:attached=>params[:attached])
    action_secure(OpenChain::CustomHandler::PoloCaEntryParser.new(f).can_view?(current_user),Entry,{:verb=>"view",:module_name=>"Polo Canada Entry Worksheets",:lock_check=>false}) {
      if params[:attached].nil?
        add_flash :errors, "You must select a file to upload." 
      elsif f.save
        f.delay.process(current_user)
        add_flash :notices, "Your file is being processed.  You'll receive a system message when it's done."
      else
        errors_to_flash f
      end
      redirect_to '/custom_features/polo_canada'
    }
  end
  def polo_efocus_download
    f = CustomFile.find params[:id] 
    action_secure(OpenChain::CustomHandler::PoloCaEntryParser.new(f).can_view?(current_user),Entry,{:verb=>"view",:module_name=>"Polo Canada Entry Worksheets",:lock_check=>false}) {
      redirect_to f.secure_url
    }
  end
  
  def kewill_isf_index
    action_secure(OpenChain::CustomHandler::KewillIsfManualParser.new(nil).can_view?(current_user),Product,{verb:"view",module_name:"Kewill ISF Manual Parser", lock_check: false}){
      @files = CustomFile.where(file_type: KEWILL_ISF).order('created_at DESC').paginate(:per_page=>20,:page=>params[:page])
      render layout: 'one_col'
    }
  end

  def kewill_isf_upload
    f = CustomFile.new(file_type: KEWILL_ISF, uploaded_by: current_user, attached: params[:attached], start_at: 0.seconds.ago)
    action_secure(OpenChain::CustomHandler::KewillIsfManualParser.new(f).can_view?(current_user),Product,{:verb=>'upload',:module_name=>"Kewill ISF Manual Parser",:lock_check=>false}) {
      if params[:attached].nil?
        add_flash :errors, "You must select a file to upload." 
      elsif f.save
        f.delay.process(current_user)
        add_flash :notices, "Your file is being processed.  You'll receive a system message when it's done."
      else
        errors_to_flash f
      end
      redirect_to '/custom_features/kewill_isf'
    }
  end

  def polo_sap_bom_index 
    action_secure(OpenChain::CustomHandler::PoloSapBomHandler.new(nil).can_view?(current_user),Product,{:verb=>"view",:module_name=>"SAP Bill of Materials Files",:lock_check=>false}) {
      @files = CustomFile.where(:file_type=>POLO_SAP_BOM).order('created_at DESC').paginate(:per_page=>20,:page=>params[:page])
      render :layout => 'one_col'
    }
  end


  def polo_sap_bom_upload
    f = CustomFile.new(:file_type=>POLO_SAP_BOM,:uploaded_by=>current_user,:attached=>params[:attached],:start_at=>0.seconds.ago)
    action_secure(OpenChain::CustomHandler::PoloSapBomHandler.new(f).can_view?(current_user),Product,{:verb=>'upload',:module_name=>"SAP Bill of Materials Files",:lock_check=>false}) {
      if params[:attached].nil?
        add_flash :errors, "You must select a file to upload." 
      elsif f.save
        f.delay.process(current_user)
        add_flash :notices, "Your file is being processed.  You'll receive a system message when it's done."
      else
        errors_to_flash f
      end
      redirect_to '/custom_features/polo_sap_bom'
    }
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
    f = CustomFile.find params[:id] 
    action_secure(OpenChain::CustomHandler::PoloSapBomHandler.new(f).can_view?(current_user),Product,{:verb=>'download',:module_name=>"SAP Bill of Materials Files",:lock_check=>false}) {
      redirect_to f.secure_url
    }
  end
  def csm_sync_index
    action_secure(current_user.edit_products?,Product,{:verb=>"view",:module_name=>"CSM Sync Files",:lock_check=>false}) {
      @files = CustomFile.where(:file_type=>CSM_SYNC).order('created_at DESC').paginate(:per_page=>20,:page=>params[:page])
      render :layout => 'one_col'
    }
  end
  def csm_sync_upload
    f = CustomFile.new(:file_type=>CSM_SYNC,:uploaded_by=>current_user,:attached=>params[:attached],:start_at=>0.seconds.ago)
    action_secure(current_user.edit_products?,Product,{:verb=>"upload",:module_name=>"CSM Sync Files",:lock_check=>false}) {
      if params[:attached].nil?
        add_flash :errors, "You must select a file to upload." 
      elsif f.save
        f.delay.process(current_user)
        add_flash :notices, "Your file is being processed.  You'll receive a system message when it's done."
      else
        errors_to_flash f
      end
      redirect_to '/custom_features/csm_sync'
    }
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
    f = CustomFile.find params[:id] 
    action_secure(current_user.edit_products?,Product,{:verb=>"download",:module_name=>"CSM Sync Files",:lock_check=>false}) {
      redirect_to f.secure_url
    }
  end

  def jcrew_parts_index
    action_secure(OpenChain::CustomHandler::JCrewPartsExtractParser.new.can_view?(current_user),Product,{:verb=>"view",:module_name=>"J Crew Parts Extract",:lock_check=>false}) {
      @files = CustomFile.where(:file_type=>JCREW_PARTS).order('created_at DESC').paginate(:per_page=>20,:page=>params[:page])
      render :layout => 'one_col'
    }
  end

  def jcrew_parts_upload
    f = CustomFile.new(:file_type=>JCREW_PARTS,:uploaded_by=>current_user,:attached=>params[:attached])
    action_secure(f.can_view?(current_user),f,{:verb=>"upload",:module_name=>"J Crew Parts Extract",:lock_check=>false}) {
      if params[:attached].nil?
        add_flash :errors, "You must select a file to upload." 
      elsif f.save
        f.delay.process(current_user)
        add_flash :notices, "Your file is being processed.  You'll receive a system message when it's done."
      else
        errors_to_flash f
      end
      redirect_to '/custom_features/jcrew_parts'
    }
  end

  def jcrew_parts_download
    f = CustomFile.find params[:id] 
    action_secure(f.can_view?(current_user),Product,{:verb=>"download",:module_name=>"J Crew Parts Extract",:lock_check=>false}) {
      redirect_to f.secure_url
    }
  end

  def polo_ca_invoices_index
    action_secure(OpenChain::CustomHandler::Polo::PoloCaInvoiceHandler.new(nil).can_view?(current_user),CommercialInvoice,{:verb=>"view",:module_name=>"Polo CA Invoices",:lock_check=>false}) {
      @files = CustomFile.where(:file_type=>POLO_CA_INVOICES).order('created_at DESC').paginate(:per_page=>20,:page=>params[:page])
      render :layout => 'one_col'
    }
  end

  def polo_ca_invoices_upload
    f = CustomFile.new(:file_type=>POLO_CA_INVOICES,:uploaded_by=>current_user,:attached=>params[:attached])
    action_secure(f.can_view?(current_user),f,{:verb=>"upload",:module_name=>"Polo CA Invoices",:lock_check=>false}) {
      if params[:attached].nil?
        add_flash :errors, "You must select a file to upload." 
      elsif f.save
        f.delay.process(current_user)
        add_flash :notices, "Your file is being processed.  You'll receive a system message when it's done."
      else
        errors_to_flash f
      end
      redirect_to '/custom_features/polo_ca_invoices'
    }
  end

  def polo_ca_invoices_download
    f = CustomFile.find params[:id] 
    action_secure(f.can_view?(current_user),CommercialInvoice,{:verb=>"download",:module_name=>"Polo CA Invoices",:lock_check=>false}) {
      redirect_to f.secure_url
    }
  end

  def ecellerate_shipment_activity_index
    action_secure(OpenChain::CustomHandler::EcellerateShipmentActivityParser.can_view?(current_user),CommercialInvoice,{:verb=>"view",:module_name=>"ECellerate Shipment Activity",:lock_check=>false}) {
      @files = CustomFile.where(:file_type=>ECELLERATE_SHIPMENT_ACTIVITY).order('created_at DESC').paginate(:per_page=>20,:page=>params[:page])
      render :layout => 'one_col'
    }
  end

  def ecellerate_shipment_activity_upload
    f = CustomFile.new(:file_type=>ECELLERATE_SHIPMENT_ACTIVITY,:uploaded_by=>current_user,:attached=>params[:attached])
    action_secure(f.can_view?(current_user),f,{:verb=>"upload",:module_name=>"Fenix Commerical Invoice Upload",:lock_check=>false}) {
      if params[:attached].nil?
        add_flash :errors, "You must select a file to upload." 
      elsif f.save
        f.delay.process(current_user)
        add_flash :notices, "Your file is being processed.  You'll receive a system message when it's done."
      else
        errors_to_flash f
      end
      redirect_to '/custom_features/ecellerate_shipment_activity'
    }
  end

  def ecellerate_shipment_activity_download
    f = CustomFile.find params[:id] 
    action_secure(f.can_view?(current_user),Shipment,{:verb=>"download",:module_name=>"Fenix Commerical Invoice Upload",:lock_check=>false}) {
      redirect_to f.secure_url
    }
  end

  def fenix_ci_load_index
    action_secure(OpenChain::CustomHandler::FenixCommercialInvoiceSpreadsheetHandler.new(nil).can_view?(current_user),CommercialInvoice,{:verb=>"view",:module_name=>"Fenix Commerical Invoice Upload",:lock_check=>false}) {
      @files = CustomFile.where(:file_type=>FENIX_CI_UPLOAD).order('created_at DESC').paginate(:per_page=>20,:page=>params[:page])
      render :layout => 'one_col'
    }
  end

  def fenix_ci_load_upload
    f = CustomFile.new(:file_type=>FENIX_CI_UPLOAD,:uploaded_by=>current_user,:attached=>params[:attached])
    action_secure(f.can_view?(current_user),f,{:verb=>"upload",:module_name=>"Fenix Commerical Invoice Upload",:lock_check=>false}) {
      if params[:attached].nil?
        add_flash :errors, "You must select a file to upload." 
      elsif f.save
        f.delay.process(current_user)
        add_flash :notices, "Your file is being processed.  You'll receive a system message when it's done."
      else
        errors_to_flash f
      end
      redirect_to '/custom_features/fenix_ci_load'
    }
  end

  def fenix_ci_load_download
    f = CustomFile.find params[:id] 
    action_secure(f.can_view?(current_user),CommercialInvoice,{:verb=>"download",:module_name=>"Fenix Commerical Invoice Upload",:lock_check=>false}) {
      redirect_to f.secure_url
    }
  end

  def lenox_shipment_status_index
    action_secure(OpenChain::CustomHandler::Lenox::LenoxShipmentStatusParser.can_view?(current_user),Shipment,{verb:'view',module_name:"Lenox OOCL Shipment Report Upload",lock_check:false}) {
      @files = CustomFile.where(file_type:LENOX_SHIPMENT).order('created_at DESC').paginate(per_page:20,page:params[:page])
    }
  end

  def lenox_shipment_status_upload
    f = CustomFile.new(:file_type=>LENOX_SHIPMENT,:uploaded_by=>current_user,:attached=>params[:attached])
    action_secure(f.can_view?(current_user),f,{:verb=>"upload",:module_name=>"Lenox OOCL Shipment Report Upload",:lock_check=>false}) {
      if params[:attached].nil?
        add_flash :errors, "You must select a file to upload." 
      elsif f.save
        f.delay.process(current_user)
        add_flash :notices, "Your file is being processed.  You'll receive a system message when it's done."
      else
        errors_to_flash f
      end
      redirect_to '/custom_features/lenox_shipment_status'
    }
  end

  def lenox_shipment_status_download
    f = CustomFile.find params[:id] 
    action_secure(f.can_view?(current_user),LENOX_SHIPMENT,{:verb=>"download",:module_name=>"Lenox OOCL Shipment Report Upload",:lock_check=>false}) {
      redirect_to f.secure_url
    }
  end

  def eddie_fenix_ci_load_index
    action_secure(OpenChain::CustomHandler::EddieBauer::EddieBauerFenixInvoiceHandler.new(nil).can_view?(current_user),CommercialInvoice,{:verb=>"view",:module_name=>"Fenix Commerical Invoice Upload",:lock_check=>false}) {
      @files = CustomFile.where(:file_type=>EDDIE_CI_UPLOAD).order('created_at DESC').paginate(:per_page=>20,:page=>params[:page])
      render :layout => 'one_col'
    }
  end

  def eddie_fenix_ci_load_upload
    f = CustomFile.new(:file_type=>EDDIE_CI_UPLOAD,:uploaded_by=>current_user,:attached=>params[:attached])
    action_secure(f.can_view?(current_user),f,{:verb=>"upload",:module_name=>"Eddie Bauer Fenix Commerical Invoice Upload",:lock_check=>false}) {
      if params[:attached].nil?
        add_flash :errors, "You must select a file to upload." 
      elsif f.save
        f.delay.process(current_user)
        add_flash :notices, "Your file is being processed.  You'll receive a system message when it's done."
      else
        errors_to_flash f
      end
      redirect_to '/custom_features/eddie_fenix_ci_load'
    }
  end

  def eddie_fenix_ci_load_download
    f = CustomFile.find params[:id] 
    action_secure(f.can_view?(current_user),EDDIE_CI_UPLOAD,{:verb=>"download",:module_name=>"Eddie Bauer Fenix Commerical Invoice Upload",:lock_check=>false}) {
      redirect_to f.secure_url
    }
  end

  def le_returns_index
    action_secure(OpenChain::CustomHandler::LandsEnd::LeReturnsParser.new(nil).can_view?(current_user),CommercialInvoice,{:verb=>"view",:module_name=>"Lands' End Returns Upload",:lock_check=>false}) {
      @files = CustomFile.where(:file_type=>LE_RETURNS_PARSER).order('created_at DESC').paginate(:per_page=>20,:page=>params[:page])
      render :layout => 'one_col'
    }
  end

  def le_returns_upload
    f = CustomFile.new(:file_type=>LE_RETURNS_PARSER,:uploaded_by=>current_user,:attached=>params[:attached])
    action_secure(f.can_view?(current_user),f,{:verb=>"upload",:module_name=>"Lands' End Returns Upload",:lock_check=>false}) {
      if params[:attached].nil?
        add_flash :errors, "You must select a file to upload." 
      elsif f.save
        f.delay.process(current_user)
        add_flash :notices, "Your file is being processed.  You'll receive an email with a merged product worksheet when it's done."
      else
        errors_to_flash f
      end
      redirect_to '/custom_features/le_returns'
    }
  end

  def le_returns_download
    f = CustomFile.find params[:id] 
    action_secure(f.can_view?(current_user),LE_RETURNS_PARSER,{:verb=>"download",:module_name=>"Lands' End Returns Upload",:lock_check=>false}) {
      redirect_to f.secure_url
    }
  end

  def le_ci_load_index
    action_secure(OpenChain::CustomHandler::LandsEnd::LeReturnsCommercialInvoiceGenerator.new(nil).can_view?(current_user),CommercialInvoice,{:verb=>"view",:module_name=>"Lands' End Commerical Invoice Upload",:lock_check=>false}) {
      @files = CustomFile.where(:file_type=>LE_CI_UPLOAD).order('created_at DESC').paginate(:per_page=>20,:page=>params[:page])
      render :layout => 'one_col'
    }
  end

  def le_ci_load_upload
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
    f = CustomFile.find params[:id] 
    action_secure(f.can_view?(current_user),LE_CI_UPLOAD,{:verb=>"download",:module_name=>"Lands' End Commerical Invoice Upload",:lock_check=>false}) {
      redirect_to f.secure_url
    }
  end

  def rl_fabric_parse_index
    action_secure(OpenChain::CustomHandler::Polo::PoloFiberContentParser.can_view?(current_user),Product,{:verb=>"view",:module_name=>"MSL Fabric Analyzer",:lock_check=>false}) {
      #nothing to do here
    }
  end

  def rl_fabric_parse_run
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
    action_secure(OpenChain::CustomHandler::Intacct::AllianceDayEndHandler.can_view?(current_user),Entry,{:verb=>"view",:module_name=>"Alliance Day End Processor",:lock_check=>false}) {
      @files = CustomFile.where(:file_type=>ALLIANCE_DAY_END).order('created_at DESC').paginate(:per_page=>20,:page=>params[:page])
    }
  end

  def alliance_day_end_upload
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
    f = CustomFile.find params[:id] 
    action_secure(f.can_view?(current_user),ALLIANCE_DAY_END,{:verb=>"download",:module_name=>"Alliance Day End Processor",:lock_check=>false}) {
      redirect_to f.secure_url
    }
  end

  def ci_load_index
    action_secure(OpenChain::CustomHandler::CiLoadHandler.can_view?(current_user),Entry,{:verb=>"view",:module_name=>"CI Load Upload",:lock_check=>false}) {
      @files = CustomFile.where(:file_type=>CI_UPLOAD).order('created_at DESC').paginate(:per_page=>20,:page=>params[:page])
    }
  end

  def ci_load_upload
    f = CustomFile.new(:file_type=>CI_UPLOAD,:uploaded_by=>current_user,:attached=>params[:attached])
    action_secure(f.can_view?(current_user),f,{:verb=>"upload",:module_name=>"CI Load Upload",:lock_check=>false}) {
      if params[:attached].nil?
        add_flash :errors, "You must select a file to upload." 
      elsif f.save
        f.delay.process(current_user)
        add_flash :notices, "Your file is being processed.  You'll receive a VFI Track message when it completes."
      else
        errors_to_flash f
      end
      redirect_to '/custom_features/ci_load'
    }
  end
  

  def ci_load_download
    f = CustomFile.find params[:id] 
    action_secure(f.can_view?(current_user),f,{:verb=>"download",:module_name=>"CI Load Upload",:lock_check=>false}) {
      redirect_to f.secure_url
    }
  end

  def fisher_ci_load_index
    action_secure(OpenChain::CustomHandler::Fisher::FisherCommercialInvoiceSpreadsheetHandler.new(nil).can_view?(current_user),Entry,{:verb=>"view",:module_name=>"Fisher CI Load Upload",:lock_check=>false}) {
      @files = CustomFile.where(:file_type=>FISHER_CI_UPLOAD).order('created_at DESC').paginate(:per_page=>20,:page=>params[:page])
    }
  end

  def fisher_ci_load_upload
    f = CustomFile.new(:file_type=>FISHER_CI_UPLOAD,:uploaded_by=>current_user,:attached=>params[:attached])
    action_secure(f.can_view?(current_user),f,{:verb=>"upload",:module_name=>"Fisher CI Load Upload",:lock_check=>false}) {
      # Verify the invoice date was supplied
      invoice_date = Date.strptime(params[:invoice_date].to_s, "%Y-%m-%d") rescue nil

      if invoice_date.nil?
        add_flash :errors, "You must enter an Invoice Date." 
      end

      if params[:attached].nil?
        add_flash :errors, "You must select a file to upload."
      end

      if !has_errors? && f.save
        CustomFile.delay.process f.id, current_user.id, {"invoice_date"=>params[:invoice_date]}
        add_flash :notices, "Your file is being processed.  You'll receive a VFI Track message when it completes."
      else
        errors_to_flash f
      end
      redirect_to '/custom_features/fisher_ci_load'
    }
  end
  
  def fisher_ci_load_download
    f = CustomFile.find params[:id] 
    action_secure(f.can_view?(current_user),f,{:verb=>"download",:module_name=>"Fisher CI Load Upload",:lock_check=>false}) {
      redirect_to f.secure_url
    }
  end

  def ascena_ca_invoices_index
    action_secure(OpenChain::CustomHandler::AscenaCaInvoiceHandler.new(nil).can_view?(current_user),CommercialInvoice,{:verb=>"view",:module_name=>"Ascena CA Invoices",:lock_check=>false}) {
      @files = CustomFile.where(:file_type=>ASCENA_CA_INVOICES).order('created_at DESC').paginate(:per_page=>20,:page=>params[:page])
      render :layout => 'one_col'
    }
  end

  def ascena_ca_invoices_upload
    f = CustomFile.new(:file_type=>ASCENA_CA_INVOICES,:uploaded_by=>current_user,:attached=>params[:attached])
    action_secure(f.can_view?(current_user),f,{:verb=>"upload",:module_name=>"Ascena CA Invoices",:lock_check=>false}) {
      if params[:attached].nil?
        add_flash :errors, "You must select a file to upload." 
      elsif f.save
        f.delay.process(current_user)
        add_flash :notices, "Your file is being processed.  You'll receive a system message when it's done."
      else
        errors_to_flash f
      end
      redirect_to '/custom_features/ascena_ca_invoices'
    }
  end

  def ascena_ca_invoices_download
    f = CustomFile.find params[:id] 
    action_secure(f.can_view?(current_user),CommercialInvoice,{:verb=>"download",:module_name=>"Ascena CA Invoices",:lock_check=>false}) {
      redirect_to f.secure_url
    }
  end

  def crew_returns_index
    action_secure(OpenChain::CustomHandler::JCrew::JCrewReturnsParser.new(nil).can_view?(current_user),Product,{:verb=>"view",:module_name=>"J.Crew Returns",:lock_check=>false}) {
      @files = CustomFile.where(:file_type=>CREW_RETURNS).order('created_at DESC').paginate(:per_page=>20,:page=>params[:page])
    }
  end

  def crew_returns_upload
    f = CustomFile.new(:file_type=>CREW_RETURNS,:uploaded_by=>current_user,:attached=>params[:attached])
    action_secure(f.can_view?(current_user),f,{:verb=>"upload",:module_name=>"J.Crew Returns",:lock_check=>false}) {
     
      if params[:attached].nil?
        add_flash :errors, "You must select a file to upload."
      end

      if !has_errors? && f.save
        CustomFile.delay.process f.id, current_user.id
        add_flash :notices, "Your file is being processed.  You'll receive a VFI Track message when it completes."
      else
        errors_to_flash f
      end
      redirect_to '/custom_features/crew_returns'
    }
  end
  
  def crew_returns_download
    f = CustomFile.find params[:id] 
    action_secure(f.can_view?(current_user),f,{:verb=>"download",:module_name=>"J.Crew Returns",:lock_check=>false}) {
      redirect_to f.secure_url
    }
  end

  def pvh_workflow_index
    action_secure(OpenChain::CustomHandler::Pvh::PvhShipmentWorkflowParser.can_view?(current_user),Shipment,{:verb=>"view",:module_name=>"PVH Workflow",:lock_check=>false}) {
      @files = CustomFile.where(:file_type=>PVH_WORKFLOW).order('created_at DESC').paginate(:per_page=>20,:page=>params[:page])
    }
  end

  def pvh_workflow_upload
    f = CustomFile.new(:file_type=>PVH_WORKFLOW,:uploaded_by=>current_user,:attached=>params[:attached])
    action_secure(f.can_view?(current_user),f,{:verb=>"upload",:module_name=>"PVH Workflow",:lock_check=>false}) {
     
      if params[:attached].nil?
        add_flash :errors, "You must select a file to upload."
      end

      if !has_errors? && f.save
        CustomFile.delay.process f.id, current_user.id
        add_flash :notices, "Your file is being processed.  You'll receive a VFI Track message when it completes."
      else
        errors_to_flash f
      end
      redirect_to '/custom_features/pvh_workflow'
    }
  end
  
  def pvh_workflow_download
    f = CustomFile.find params[:id] 
    action_secure(f.can_view?(current_user),f,{:verb=>"download",:module_name=>"PVH Workflow",:lock_check=>false}) {
      redirect_to f.secure_url
    }
  end

end
