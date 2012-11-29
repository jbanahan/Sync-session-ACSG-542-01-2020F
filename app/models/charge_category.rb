class ChargeCategory < ActiveRecord::Base
  belongs_to :company

  validates_presence_of :company
  validates_presence_of :charge_code
  validates_presence_of :category
  validates_uniqueness_of :charge_code, {:scope=>:company_id}
  
end
