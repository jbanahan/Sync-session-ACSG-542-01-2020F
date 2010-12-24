class ItemChangeSubscription < ActiveRecord::Base
  belongs_to  :shipment
  belongs_to  :order
  belongs_to  :product
  belongs_to  :user
  
  validates :user, :presence => true
  
  def app_message?
    return self.app_message
  end
  
  def email?
    return self.email
  end
end
