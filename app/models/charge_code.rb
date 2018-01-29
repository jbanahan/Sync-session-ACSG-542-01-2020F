# == Schema Information
#
# Table name: charge_codes
#
#  id          :integer          not null, primary key
#  code        :string(255)
#  description :string(255)
#  apply_hst   :boolean
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#

class ChargeCode < ActiveRecord::Base
  validates_uniqueness_of :code
end
