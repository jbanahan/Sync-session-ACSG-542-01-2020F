class EmailsController < ApplicationController
  def show
    e = Email.find(params[:id])
    action_secure e.can_view?(current_user), e,{:lock_check=>false,:module_name=>"email",:verb=>"edit"} do
      @email = e
    end
  end
end
