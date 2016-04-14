class TradeLanesController < ApplicationController
  def index
    action_secure(current_user.view_trade_lanes?,nil,{:lock_check => false, :verb => "view", :module_name=>"trade lanes"}) {
    }
  end
end
