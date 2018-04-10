# == Schema Information
#
# Table name: delivery_lines
#
#  created_at  :datetime         not null
#  delivery_id :integer
#  id          :integer          not null, primary key
#  line_number :integer
#  product_id  :integer
#  quantity    :decimal(13, 4)
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_delivery_lines_on_delivery_id  (delivery_id)
#

class DeliveryLine < ActiveRecord::Base
  include LinesSupport
  include CustomFieldSupport
  include ShallowMerger
  include UpdateModelFieldsSupport
  belongs_to :delivery

  validates_uniqueness_of :line_number, :scope => :delivery_id	
	def find_same
    found = DeliveryLine.where({:delivery_id => self.delivery_id, :line_number => self.line_number})
    raise "Found multiple delivery lines with the same delivery id #{self.delivery_id} & line number #{self.line_number}" if found.size > 1
    return found.empty? ? nil : found.first
  end
  
  dont_shallow_merge :DeliveryLine, ['id','created_at','updated_at','line_number']

  private
  def parent_obj #supporting method for LinesSupport
    self.delivery
  end
  
  def parent_id_where #supporting method for LinesSupport
    return :delivery_id => self.delivery_id
  end
end
