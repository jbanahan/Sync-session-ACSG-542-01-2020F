class ShipmentLine < ActiveRecord::Base
  include LinesSupport
  include CustomFieldSupport
  include ShallowMerger
  belongs_to :shipment

  validates_uniqueness_of :line_number, :scope => :shipment_id	
  
  dont_shallow_merge :ShipmentLine, ['id','created_at','updated_at','line_number']

  def related_orders
    s = Set.new
    self.piece_sets.each do |p|
      s.add p.order_line.order unless p.order_line.nil?
    end
    s
  end

  def find_same
    r = ShipmentLine.where(:shipment_id=>self.shipment_id,:line_number=>self.line_number)
    raise "Multiple shipment lines found for shipment #{self.shipment_id} and line #{self.line_number}" if r.size > 1
    r.empty? ? nil : r.first
  end
  private
  def parent_obj #supporting method for LinesSupport
    self.shipment
  end
  
  def parent_id_where #supporting method for LinesSupport
    return :shipment_id => self.shipment.id
  end
end
