class ChargeCode < ActiveRecord::Base
  validates_uniqueness_of :code
end
