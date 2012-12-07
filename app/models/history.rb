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
