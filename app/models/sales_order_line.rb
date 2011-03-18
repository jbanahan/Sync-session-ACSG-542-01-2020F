class SalesOrderLine < ActiveRecord::Base
  include LinesSupport
  include CustomFieldSupport
  include ShallowMerger

  dont_shallow_merge :SalesOrderLine, ['id','created_at','updated_at','line_number']
  
  belongs_to :product
  belongs_to :sales_order
  
  has_many  :piece_sets, :dependent => :destroy
  has_many   :histories, :dependent => :destroy

  before_validation :set_line_number
  before_validation :set_ordered_quantity

  validates :product, :presence => true
  validates_uniqueness_of :line_number, :scope => :sales_order_id
  
  def find_same
    found = SalesOrderLine.where({:sales_order_id => self.sales_order_id, :line_number => self.line_number})
    raise "Found multiple sale lines with the same order id #{self.sales_order_id} & line number #{self.line_number}" if found.size > 1
    return found.empty? ? nil : found.first
  end
  def locked?
    return (!parent_obj.nil? && parent_obj.locked?)
  end
  
  private
  def parent_obj #supporting method for LinesSupport
    self.sales_order
  end
  
  def parent_id_where #supporting method for LinesSupport
    return :sales_order_id => self.sales_order_id
  end  
end
