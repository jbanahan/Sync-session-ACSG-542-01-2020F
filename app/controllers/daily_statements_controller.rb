require 'open_chain/custom_handler/vandegrift/kewill_statement_requester'

class DailyStatementsController < ApplicationController

  def set_page_title
    @page_title ||= "Daily Statement"
  end

  def index
    if current_user.view_statements?
      flash.keep
      redirect_to advanced_search CoreModule::CUSTOMS_DAILY_STATEMENT, params[:force_search]
    else
      error_redirect "You do not have permission to view Statements."
    end
  end

  def show
    if current_user.view_statements?
      statement = DailyStatement.find params[:id]
      action_secure(statement.can_view?(current_user), statement, {:lock_check=>false,:verb=>"view",:module_name=>"statement"}) {
        @statement = statement
      }
    else
      error_redirect "You do not have permission to view Statements."
    end
  end

  def reload
    statement = DailyStatement.find params[:id]
    if current_user.company.master? && statement.can_view?(current_user)
      OpenChain::CustomHandler::Vandegrift::KewillStatementRequester.delay.request_daily_statements [statement.statement_number]
      add_flash :notices, "Updated statement has been requested.  Please allow 10 minutes for it to appear."
    end

    redirect_to statement
  end
end
