class Address < ActiveRecord::Base
  belongs_to :company
	belongs_to :country
	
	def self.find_shipping
		return self.where(["shipping = ?",true])
	end

end
