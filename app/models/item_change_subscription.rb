# == Schema Information
#
# Table name: item_change_subscriptions
#
#  app_message           :boolean
#  broker_invoice_id     :integer
#  commercial_invoice_id :integer
#  company_id            :integer
#  container_id          :integer
#  created_at            :datetime         not null
#  delivery_id           :integer
#  email                 :boolean
#  entry_id              :integer
#  id                    :integer          not null, primary key
#  order_id              :integer
#  product_id            :integer
#  sales_order_id        :integer
#  security_filing_id    :integer
#  shipment_id           :integer
#  updated_at            :datetime         not null
#  user_id               :integer
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
