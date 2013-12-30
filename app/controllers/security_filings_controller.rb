class SecurityFilingsController < ApplicationController
  def root_class
    SecurityFiling
  end
  def index
    flash.keep
    redirect_to advanced_search CoreModule::SECURITY_FILING, params[:force_search]
  end
  def show
    sf = SecurityFiling.find(params[:id])
    action_secure(sf.can_view?(current_user),sf,{:verb=>'view',:module_type=>CoreModule::SECURITY_FILING.label}) {
      @security_filing = sf
      render :layout=>'one_col'
    }
  end
end
