# == Schema Information
#
# Table name: charge_categories
#
#  category    :string(255)
#  charge_code :string(255)
#  company_id  :integer
#  created_at  :datetime         not null
#  id          :integer          not null, primary key
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_charge_categories_on_company_id  (company_id)
#

class ChargeCategory < ActiveRecord::Base
  attr_accessible :category, :charge_code, :company_id
  
  belongs_to :company

  validates_presence_of :company
  validates_presence_of :charge_code
  validates_presence_of :category
  validates_uniqueness_of :charge_code, {:scope=>:company_id}
  
end
