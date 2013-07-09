require 'open_chain/custom_handler/polo_csm_sync_handler'
require 'open_chain/custom_handler/polo_ca_entry_parser'
require 'open_chain/custom_handler/polo_sap_bom_handler'
require 'open_chain/custom_handler/j_crew_parts_extract_parser'

class CustomFeaturesController < ApplicationController
  CSM_SYNC = 'OpenChain::CustomHandler::PoloCsmSyncHandler'
  CA_EFOCUS = 'OpenChain::CustomHandler::PoloCaEntryParser'
  POLO_SAP_BOM = 'OpenChain::CustomHandler::PoloSapBomHandler'
  JCREW = 'OpenChain::CustomHandler::JCrewPartsExtractParser'

  def index
    render :layout=>'one_col'
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
      @files = CustomFile.where(:file_type=>JCREW).order('created_at DESC').paginate(:per_page=>20,:page=>params[:page])
      render :layout => 'one_col'
    }
  end

  def jcrew_parts_upload
    f = CustomFile.new(:file_type=>JCREW,:uploaded_by=>current_user,:attached=>params[:attached])
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
  
end
