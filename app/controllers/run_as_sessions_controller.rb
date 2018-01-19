class RunAsSessionsController < ApplicationController

  def set_page_title
    @page_title ||= "Run As Session"
  end

  def index
    redirect_to advanced_search CoreModule::RUN_AS_SESSION, params[:force_search]
  end

  def show
    @run_as_session = RunAsSession.find(params[:id])
  end
end