class HmI2DrawbackLine < ActiveRecord::Base
  attr_accessible :carrier, :carrier_tracking_number, :consignment_line_number, :consignment_number,
                  :converted_date, :country_code, :customer_order_reference, :export_received,
                  :invoice_line_number, :invoice_number, :item_value, :origin_country_code, :part_description,
                  :part_number, :po_line_number, :po_number, :quantity, :return_reference_number,
                  :shipment_date, :shipment_type
end