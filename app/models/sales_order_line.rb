class SalesOrderLine < ActiveRecord::Base
  include LinesSupport
  
  belongs_to :product
  belongs_to :sales_order
  
  has_many  :piece_sets, :dependent => :destroy
  has_many   :histories, :dependent => :destroy

  before_validation :set_line_number
  before_validation :set_ordered_quantity

  validates :product, :presence => true
  validates_uniqueness_of :line_number, :scope => :sales_order_id
  
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
