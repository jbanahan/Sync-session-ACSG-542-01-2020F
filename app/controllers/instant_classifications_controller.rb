class InstantClassificationsController < ApplicationController

  def index
    admin_secure {
      @instant_classifications = InstantClassification.ranked
      render :layout => 'one_col'
    }
  end

  def update_rank 
    admin_secure {
      params[:sort_order].each_with_index do |ic_id,index|
        InstantClassification.find(ic_id).update_attributes(:rank=>index)
      end
      render :text => "" #effectively noop
    }
  end

end
