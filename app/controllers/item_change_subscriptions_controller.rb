class ItemChangeSubscriptionsController < ApplicationController
  def index
    @item_change_subscriptions = ItemChangeSubscription.where({:user_id => current_user.id})
    respond_to do |format|
      format.html { render :layout => 'one_col' }
      format.xml  { render :xml => @orders }
    end
  end
  
  def create
    ics = ItemChangeSubscription.new(params[:item_change_subscription])
    e_msg = ics.user == current_user ? can_view(ics) : "You can only subscribe for yourself, not another user."
    if e_msg.nil?
      if !ics.save
        errors_to_flash ics
      end
      redirect_to request.referrer
    else
      error_redirect e_msg
    end
  end
  
  def update
    ics = ItemChangeSubscription.find(params[:id])
    if current_user.id.to_s == params[:item_change_subscription][:user_id]
      if ics.update_attributes(params[:item_change_subscription])
        add_flash :notices, "Subscription was updated successfully."
        if !ics.email? && !ics.app_message?
          ics.destroy
        end
      else
        errors_to_flash ics
      end
      redirect_to request.referrer
    else
      error_redirect "You do not have permission to edit another user's subscription."
    end    
  end
  
  def destroy
    ics = ItemChangeSubscription.find(params[:id])
    if ics.user == current_user
      ics.destroy
      errors_to_flash ics
      redirect_to request.referrer
    else
      error_redirect "You do not have permission to delete another user's subscription."
    end
  end
  
  private 
  
  def can_view(ics)
    if !ics.order.nil? && !ics.order.can_view?(current_user)
      return "You do not have permission to subscribe to this order."
    end
    if !ics.shipment.nil? && !ics.shipment.can_view?(current_user)
      return "You do not have permission to subscribe to this shipment."
    end    
    if !ics.product.nil? && !ics.product.can_view?(current_user)
      return "You do not have permission to subscribe to this product."
    end    
  end
end
