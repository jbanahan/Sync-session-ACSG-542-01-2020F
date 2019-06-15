# == Schema Information
#
# Table name: charge_codes
#
#  apply_hst   :boolean
#  code        :string(255)
#  created_at  :datetime         not null
#  description :string(255)
#  id          :integer          not null, primary key
#  updated_at  :datetime         not null
#

class ChargeCode < ActiveRecord::Base
  attr_accessible :apply_hst, :code, :description
  
  validates_uniqueness_of :code
end
