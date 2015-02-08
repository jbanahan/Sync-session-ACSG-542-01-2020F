require 'open_chain/custom_handler/duty_calc/export_history_parser'
require 'open_chain/custom_handler/duty_calc/claim_audit_parser'
class DrawbackClaimsController < ApplicationController 
  def index
    action_secure(current_user.view_drawback?, current_user, {:verb => "view", :lock_check => false, :module_name=>"drawback claims"}) do
      @claims = secure.order("IFNULL(sent_to_customs_date,adddate(now(),INTERVAL 100 YEAR)) DESC, id DESC").paginate(:per_page => 20, :page => params[:page])
      render :layout=>'one_col'
    end
  end
  
  def show
    claim = DrawbackClaim.find params[:id]
    action_secure(claim.can_view?(current_user), claim, {:verb => "view", :lock_check => false, :module_name=>"drawback claim"}) do
      @claim = claim
    end
  end

  def edit
    claim = DrawbackClaim.find params[:id]
    action_secure(claim.can_edit?(current_user),claim,:verb=>'edit',:lock_check=>false,:module_name=>'drawback claim') {
      @drawback_claim = claim
    }
  end
  def update
    claim = DrawbackClaim.find params[:id]
    action_secure(claim.can_edit?(current_user),claim,:verb=>'edit',:lock_check=>false,:module_name=>'drawback claim') {
      claim.update_attributes(params[:drawback_claim])
      errors_to_flash claim
      if claim.errors.empty?
        add_flash :notices, "Drawback saved successfully."
      end
      redirect_to claim
    }
  end
  def new
    action_secure(current_user.edit_drawback?,current_user,:verb=>'edit',:lock_check=>false,:module_name=>'drawback claim') {
      @drawback_claim = DrawbackClaim.new
    }
  end
  def create
    action_secure(current_user.edit_drawback?,current_user,:verb=>'edit',:lock_check=>false,:module_name=>'drawback claim') {
      d = DrawbackClaim.create(params[:drawback_claim])
      errors_to_flash d
      if d.errors.full_messages.size == 0
        add_flash :notices, "Drawback saved successfully."
        redirect_to DrawbackClaim
      else
        redirect_to request.referrer 
      end
    }
  end

  REPORT_PARSERS = {
    'exphist'=>OpenChain::CustomHandler::DutyCalc::ExportHistoryParser,
    'audrpt'=>OpenChain::CustomHandler::DutyCalc::ClaimAuditParser
  }
  def process_report
    claim = DrawbackClaim.find(params[:id])
    action_secure(claim.can_edit?(current_user),claim,:verb=>'edit',:lock_check=>false,:module_name=>'drawback claim') {
      parser = REPORT_PARSERS[params[:process_type]]
      if parser.nil?
        add_flash :errors, "Invalid parser type #{params[:process_type]}"
      else
        parser.delay.process_excel_from_attachment params[:attachment_id], current_user.id
        add_flash :notices, "Report is being processed.  You'll receive a system message when it is complete."
      end
      redirect_to claim
    }
  end

  def secure
    DrawbackClaim.viewable(current_user) 
  end
end
