class DailyStatementsController < ApplicationController

  def set_page_title
    @page_title || "Monthly Statement"
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
end