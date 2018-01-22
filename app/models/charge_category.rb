# == Schema Information
#
# Table name: charge_categories
#
#  id          :integer          not null, primary key
#  company_id  :integer
#  charge_code :string(255)
#  category    :string(255)
#  created_at  :datetime
#  updated_at  :datetime
#
# Indexes
#
#  index_charge_categories_on_company_id  (company_id)
#

class ChargeCategory < ActiveRecord::Base
  belongs_to :company

  validates_presence_of :company
  validates_presence_of :charge_code
  validates_presence_of :category
  validates_uniqueness_of :charge_code, {:scope=>:company_id}
  
end
