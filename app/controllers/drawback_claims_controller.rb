require 'open_chain/custom_handler/duty_calc/export_history_parser'
require 'open_chain/custom_handler/duty_calc/claim_audit_parser'
require 'open_chain/business_rule_validation_results_support'
require 'open_chain/report/drawback_audit_report'

class DrawbackClaimsController < ApplicationController
  include OpenChain::BusinessRuleValidationResultsSupport

  def index
    flash.keep
    redirect_to advanced_search CoreModule::DRAWBACK_CLAIM, params[:force_search]
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
      claim.update_model_field_attributes params[:drawback_claim]
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
      d = DrawbackClaim.new
      d.update_model_field_attributes params[:drawback_claim]
      errors_to_flash d
      if d.errors.full_messages.size == 0
        add_flash :notices, "Drawback saved successfully."
        redirect_to DrawbackClaim
      else
        redirect_to request.referrer
      end
    }
  end
  def clear_claim_audits
    claim = DrawbackClaim.find params[:id]
    action_secure(claim.can_edit?(current_user),claim,:verb=>'edit',:lock_check=>false,:module_name=>'drawback claim') {
      DrawbackClaimAudit.where(drawback_claim_id:claim.id).delete_all
      add_flash :notices, 'Claim Audits cleared.'
      redirect_to claim
    }
  end
  def clear_export_histories
    claim = DrawbackClaim.find params[:id]
    action_secure(claim.can_edit?(current_user),claim,:verb=>'edit',:lock_check=>false,:module_name=>'drawback claim') {
      DrawbackExportHistory.where(drawback_claim_id:claim.id).delete_all
      add_flash :notices, 'Export Histories cleared.'
      redirect_to claim
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
        parser.delay.process_from_attachment params[:attachment_id], current_user.id
        add_flash :notices, "Report is being processed.  You'll receive a system message when it is complete."
      end
      redirect_to claim
    }
  end

  def audit_report
    claim = DrawbackClaim.find(params[:id])
    action_secure(claim.can_view?(current_user), claim) {
    OpenChain::Report::DrawbackAuditReport.new.run_and_attach(current_user, claim.id)
    add_flash :notices, "Report is being processed.  You'll receive a system message when it is complete."
    redirect_to request.referrer
    }
  end

  def secure
    DrawbackClaim.viewable(current_user)
  end

  def validation_results
    generic_validation_results(DrawbackClaim.find params[:id])
  end
end
