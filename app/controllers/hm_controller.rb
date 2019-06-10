# H&M specific screens

class HmController < ApplicationController

  before_filter :security_check
  def index

  end
  
  def show_po_lines
    @no_action_bar = true #implements it's own via show_po_lines.html.erb
  end

  private
  def security_check
    if !current_user.company.master? || !MasterSetup.get.custom_feature?('H&M')
      error_redirect "You do not have permission to view this page" 
    end
  end
end
