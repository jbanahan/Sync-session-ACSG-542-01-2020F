class MilestonePlan < ActiveRecord::Base
  
  has_many :search_criterions
  
  validates :name, :presence => true
  validates :test_rank, :presence => true
  validates_uniqueness_of :name, :scope => :inbound
  validates_uniqueness_of :test_rank, :scope => :inbound
  
  accepts_nested_attributes_for :search_criterions, :allow_destroy => true, 
    :reject_if => lambda { |a| 
      r_val = false
      [:model_field_uid,:operator,:value].each { |f|
        r_val = true if a[f].blank?
      } 
      r_val
    }
  
  scope :ranked, order("milestone_plans.test_rank ASC")
  
  def locked?  
    false #no concept of locking, this is hear for ApplicationController.action_secure
  end
  
  def direction
    self.inbound? ? "Inbound" : "Outbound"
  end
  
  def find_matching_piece_sets
    p = PieceSet.
      joins("LEFT OUTER JOIN order_lines on order_lines.id = piece_sets.order_line_id").
      joins("LEFT OUTER JOIN orders on orders.id = order_lines.order_id").
      joins("LEFT OUTER JOIN shipments on shipments.id = piece_sets.shipment_id").
      joins("LEFT OUTER JOIN sales_order_lines on sales_order_lines.id = piece_sets.sales_order_line_id").
      joins("LEFT OUTER JOIN sales_orders on sales_orders.id = sales_order_lines.sales_order_id").
      joins("LEFT OUTER JOIN deliveries on deliveries.id = piece_sets.delivery_id").
      joins("LEFT OUTER JOIN products on products.id = piece_sets.product_id")
    self.search_criterions.each do |s|
      p = s.apply(p)
    end
    p
  end
  
  def matches?(piece_set)
    self.find_matching_piece_sets.where("piece_sets.id = ?",piece_set.id).length > 0
  end
end
