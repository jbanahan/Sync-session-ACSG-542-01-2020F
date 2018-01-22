# == Schema Information
#
# Table name: divisions
#
#  id         :integer          not null, primary key
#  name       :string(255)
#  company_id :integer
#  created_at :datetime
#  updated_at :datetime
#

class Division < ActiveRecord::Base
  belongs_to	:company
	has_many		:orders 
	has_many		:products
	
	def has_children?
	  self.orders.size >0 || self.products.size >0
	end
end
