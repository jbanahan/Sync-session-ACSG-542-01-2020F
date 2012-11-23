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
      @bad_exports = @claim.exports_not_in_import.paginate(:page=>params[:page],:per_page=>20)
    end
  end

  def secure
    DrawbackClaim.viewable(current_user) 
  end
end
