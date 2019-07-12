class HmReceiptLine < ActiveRecord::Base
  attr_accessible :location_code, :delivery_date, :ecc_variant_code, :order_number,
                  :production_country, :quantity, :sku, :season, :converted_date
end