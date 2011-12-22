class PowerOfAttorney < ActiveRecord::Base
  belongs_to :company
  belongs_to :user, :foreign_key => :uploaded_by, :class_name => "User"
end
