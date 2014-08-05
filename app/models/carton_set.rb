class CartonSet < ActiveRecord::Base
  belongs_to :shipment, inverse_of: :carton_sets
  has_many :shipment_lines, inverse_of: :carton_set
end
