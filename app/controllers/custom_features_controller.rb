require 'open_chain/custom_handler/eddie_bauer/eddie_bauer_fenix_invoice_handler'
require 'open_chain/custom_handler/fenix_commercial_invoice_spreadsheet_handler'
require 'open_chain/custom_handler/j_crew_parts_extract_parser'
require 'open_chain/custom_handler/kewill_isf_manual_parser'
require 'open_chain/custom_handler/lenox/lenox_shipment_status_parser'
require 'open_chain/custom_handler/polo_ca_entry_parser'
require 'open_chain/custom_handler/polo_csm_sync_handler'
require 'open_chain/custom_handler/polo/polo_ca_invoice_handler'
require 'open_chain/custom_handler/polo_sap_bom_handler'
require 'open_chain/custom_handler/under_armour/ua_tbd_report_parser'
require 'open_chain/custom_handler/under_armour/ua_winshuttle_product_generator'
require 'open_chain/custom_handler/under_armour/ua_winshuttle_schedule_b_generator'

class CustomFeaturesController < ApplicationController
  CA_EFOCUS = 'OpenChain::CustomHandler::PoloCaEntryParser'
  CSM_SYNC = 'OpenChain::CustomHandler::PoloCsmSyncHandler'
  EDDIE_CI_UPLOAD = 'OpenChain::CustomHandler::EddieBauer::EddieBauerFenixInvoiceHandler'
  FENIX_CI_UPLOAD = 'OpenChain::CustomHandler::FenixCommercialInvoiceSpreadsheetHandler'
  JCREW_PARTS = 'OpenChain::CustomHandler::JCrewPartsExtractParser'
  KEWILL_ISF = 'OpenChain::CustomHandler::KewillIsfManualParser'
  LENOX_SHIPMENT = 'OpenChain::CustomHandler::Lenox::LenoxShipmentStatusParser'
  POLO_CA_INVOICES = 'OpenChain::CustomHandler::Polo::PoloCaInvoiceHandler'
  POLO_SAP_BOM = 'OpenChain::CustomHandler::PoloSapBomHandler'
  UA_TBD_REPORT_PARSER = 'OpenChain::CustomHandler::UnderArmour::UaTbdReportParser'

  def index
    render :layout=>'one_col'
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
  
end
