# == Schema Information
#
# Table name: histories
#
#  broker_invoice_id     :integer
#  commercial_invoice_id :integer
#  company_id            :integer
#  container_id          :integer
#  created_at            :datetime         not null
#  delivery_id           :integer
#  entry_id              :integer
#  history_type          :string(255)
#  id                    :integer          not null, primary key
#  order_id              :integer
#  order_line_id         :integer
#  product_id            :integer
#  sales_order_id        :integer
#  sales_order_line_id   :integer
#  security_filing_id    :integer
#  shipment_id           :integer
#  updated_at            :datetime         not null
#  user_id               :integer
#  walked                :datetime
#
# Indexes
#
#  index_histories_on_container_id        (container_id)
#  index_histories_on_security_filing_id  (security_filing_id)
#

class History < ActiveRecord::Base
  belongs_to  :order
  belongs_to  :product
  belongs_to  :shipment
  belongs_to  :user
  belongs_to  :company
  belongs_to  :order_line
  belongs_to  :sales_order
  belongs_to  :delivery
  belongs_to  :security_filing
  
  has_many    :history_details
  
  validates   :history_type, :presence => true
  
  def details_hash
    r = Hash.new
    self.history_details.each do |d|
      r[d.source_key.intern] = d.value
    end
    return r
  end
  
  def self.create_order_changed(order, current_user, link_back)
    create_object_changed(:order,order,"Order",order.order_number,current_user,link_back)
  end
  def self.create_shipment_changed(shipment, current_user, link_back)
    create_object_changed(:shipment,shipment,"Shipment",shipment.reference,current_user,link_back)
  end
  def self.create_product_changed(product, current_user, link_back)
    create_object_changed(:product,product,"Product",product.unique_identifier,current_user,link_back)
  end
  def self.create_delivery_changed(delivery, current_user, link_back)
    create_object_changed(:delivery,delivery,"Delivery",delivery.reference,current_user,link_back)
  end

  def self.purge reference_date
    History.where("created_at < ?", reference_date).find_each do |history|
      history.destroy
    end
  end
  
  private
  def self.create_object_changed(type_symbol,obj,type_name,identifier,current_user,link_back)
    h = History.create(type_symbol => obj, :user => current_user, :history_type => 'object_change')
    create_item_changed_details(h,type_name,identifier,link_back)
  end
  def self.create_item_changed_details(h,type,identifier,link)
    d_hash = Hash["type" => type, "identifier" => identifier, "link" => link]
    d_hash.each do |k,v|
      d = h.history_details.build(:source_key => k, :value => v)
      d.save
    end
  end
end
