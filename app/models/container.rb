class Container < ActiveRecord::Base
  include CoreObjectSupport
  belongs_to :entry, inverse_of: :containers
  belongs_to :shipment, inverse_of: :containers, touch: true
  has_many :shipment_lines, dependent: :destroy, inverse_of: :container
  has_many :commercial_invoice_lines, inverse_of: :container
  attr_accessible :container_number, :container_size, :goods_description, :quantity, :size_description, :teus, :uom, :weight, :seal_number


  def self.parse_container_size_description description
    case description
    when /Standard Dry 40 (ft\.?|foot)/i
      "40DV"
    when /High Cube 40 (ft\.?|foot)/i
      "40HQ"
    when /Standard Dry 20 (ft\.?|foot)/i
      "20DV"
    when /High Cube 45 (ft\.?|foot)/i
      "45HQ"
    else
      nil
    end
  end
end
