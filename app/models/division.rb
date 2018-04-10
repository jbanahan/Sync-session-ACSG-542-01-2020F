# == Schema Information
#
# Table name: divisions
#
#  company_id :integer
#  created_at :datetime         not null
#  id         :integer          not null, primary key
#  name       :string(255)
#  updated_at :datetime         not null
#

class Division < ActiveRecord::Base
  belongs_to	:company
	has_many		:orders 
	has_many		:products
	
	def has_children?
	  self.orders.size >0 || self.products.size >0
	end
end
