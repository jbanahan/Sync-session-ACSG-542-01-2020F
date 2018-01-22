# == Schema Information
#
# Table name: item_change_subscriptions
#
#  id                    :integer          not null, primary key
#  user_id               :integer
#  order_id              :integer
#  shipment_id           :integer
#  product_id            :integer
#  app_message           :boolean
#  email                 :boolean
#  created_at            :datetime
#  updated_at            :datetime
#  sales_order_id        :integer
#  delivery_id           :integer
#  entry_id              :integer
#  broker_invoice_id     :integer
#  commercial_invoice_id :integer
#  security_filing_id    :integer
#  container_id          :integer
#  company_id            :integer
#
# Indexes
#
#  index_item_change_subscriptions_on_company_id          (company_id)
#  index_item_change_subscriptions_on_container_id        (container_id)
#  index_item_change_subscriptions_on_security_filing_id  (security_filing_id)
#

class ItemChangeSubscription < ActiveRecord::Base
  belongs_to  :shipment
  belongs_to  :order
  belongs_to  :product
  belongs_to  :user
  belongs_to  :sales_order
  belongs_to  :delivery
  belongs_to  :security_filing
  
  validates :user, :presence => true
  
  def app_message?
    return self.app_message
  end
  
  def email?
    return self.email
  end
end
