# == Schema Information
#
# Table name: sales_order_lines
#
#  created_at     :datetime         not null
#  id             :integer          not null, primary key
#  line_number    :integer
#  price_per_unit :decimal(13, 4)
#  product_id     :integer
#  quantity       :decimal(13, 4)
#  sales_order_id :integer
#  updated_at     :datetime         not null
#
# Indexes
#
#  index_sales_order_lines_on_sales_order_id  (sales_order_id)
#

class SalesOrderLine < ActiveRecord::Base
  include LinesSupport
  include CustomFieldSupport
  include ShallowMerger
  include UpdateModelFieldsSupport

  attr_accessible :line_number, :price_per_unit, :product_id, :quantity, :sales_order_id

  dont_shallow_merge :SalesOrderLine, ['id', 'created_at', 'updated_at', 'line_number']

  belongs_to :sales_order

  has_many   :histories, :dependent => :destroy

  validates_uniqueness_of :line_number, :scope => :sales_order_id

  def delivery_qty
    q = 0
    self.piece_sets.each {|p| q+= p.quantity unless p.delivery_line_id.nil?}
    q
  end

  def find_same
    found = SalesOrderLine.where({:sales_order_id => self.sales_order_id, :line_number => self.line_number})
    raise "Found multiple sale lines with the same order id #{self.sales_order_id} & line number #{self.line_number}" if found.size > 1
    return found.empty? ? nil : found.first
  end

  private
  def parent_obj # supporting method for LinesSupport
    self.sales_order
  end

  def parent_id_where # supporting method for LinesSupport
    return :sales_order_id => self.sales_order_id
  end
end
