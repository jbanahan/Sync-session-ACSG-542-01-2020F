class CustomDefinition < ActiveRecord::Base
  validates  :label, :presence => true
  validates  :data_type, :presence => true
  validates  :module_type, :presence => true
	
	has_many   :custom_values, :dependent => :destroy
	
	def date?
	  (!self.data_type.nil?) && self.data_type=="date"
	end
	
	def data_column
		"#{self.data_type}_value"
	end
	
	def can_edit?(user)
		user.company.master?
	end
	
	def can_view?(user)
	  user.company.master?
	end
	
	def locked?
		false
	end
end
