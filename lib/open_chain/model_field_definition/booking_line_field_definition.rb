module OpenChain
  module ModelFieldDefinition
    module BookingLineFieldDefinition

      def core_module
        CoreModule::BOOKING_LINE
      end

      def add_booking_line_fields
        add_fields core_module, [
         [1, :bkln_line_number, :line_number, "Line Number", {:data_type=>:integer}],
         [2, :bkln_quantity, :quantity, "Quantity Booked", {:data_type=>:decimal}],
         [3, :bkln_gross_kgs, :gross_kgs, "Gross Weights (KGS)", {:data_type=>:integer}],
         [4, :bkln_cbms, :cbms, "CBMS", {:data_type=>:integer}],
         [5, :bkln_carton_qty, :carton_qty, "Carton Quantity", {:data_type=>:integer}],
         [6, :bkln_carton_set_uid,:carton_set_id,"Carton Set Unique ID",
          {data_type: :integer,
           import_lambda: lambda {|sl,id|
             return "#{ModelField.find_by_uid(:bkln_carton_set_uid).label} was blank." if id.blank?
             cs = CartonSet.find_by_id id
             return "Carton Set with ID #{id} not found. Ignored." unless cs
             return "#{ModelField.find_by_uid(:bkln_carton_set_uid).label} is not part of this shipment and was ignored." unless cs.shipment_id == sl.shipment_id
             sl.carton_set_id = cs.id
             "#{ModelField.find_by_uid(:bkln_carton_set_uid).label} set to #{cs.id}."
           }
          }],
         [7, :bkln_order_and_line_number, :order_and_line_number,"Order and Line Number", {
              data_type: :string,
              read_only: true,
              export_lambda: lambda { |bl| bl.customer_order_and_line_number },
              qualified_field_name: "(SELECT CONCAT_WS(' - ', orders.customer_order_number, order_lines.line_number) FROM booking_lines
JOIN order_lines ON order_lines.id = order_line_id
JOIN orders ON orders.id = order_lines.order_id
WHERE orders.id = order_lines.order_id)"
           }],
         [8, :bkln_order_id, :order_id, "Order ID", {
               data_type: :integer,
               export_lambda: lambda{|bl| bl.order_line.try(:order).try(:id) || bl.order_id }
           }],
         [9,:bkln_puid, :unique_identifier,"Product Unique ID", {
                        :import_lambda => lambda {|detail,data|
                          return "Product not changed." if detail.product && detail.product.unique_identifier==data
                          p = Product.where(:unique_identifier=>data).first
                          return "Product not found with unique identifier #{data}" if p.nil?
                          detail.product = p
                          return "Product set to #{data}"
                        },
                        :export_lambda => lambda {|detail|
                          product = detail.product || detail.order_line.try(:product)
                          if product
                            return product.unique_identifier
                          else
                            return nil
                          end
                        },
                        :qualified_field_name => "(SELECT products.unique_identifier FROM booking_lines
JOIN order_lines ON order_lines.id = order_line_id
JOIN products ON products.id = booking_lines.product_id OR products.id = order_lines.product_id)"
                    }],
        [10,:bkln_pname, :name,"Product Name",{
                              :import_lambda => lambda {|detail,data|
                                "Product name cannot be set by import."
                              },
                              :export_lambda => lambda {|detail|
                                product = detail.product || detail.order_line.try(:product)
                                if product
                                  return product.name
                                else
                                  return nil
                                end
                              },
                              :qualified_field_name => "(SELECT products.name FROM booking_lines
JOIN order_lines ON order_lines.id = order_line_id
JOIN products ON products.id = booking_lines.product_id OR products.id = order_lines.product_id)",
                              :history_ignore => true,
                              :read_only => true
                          }],
        [11, :bkln_prod_id, :id,"Product Name", {user_accessible: false,
                                                 history_ignore: true,
                                                 :import_lambda => lambda {|detail, data, user|
                                                   product_id = data.to_i
                                                   if detail.product_id != product_id && !(prod = Product.where(id: product_id).first).nil?
                                                     detail.product  = prod if prod.can_view?(user)
                                                   end
                                                   ""
                                                 }
                          }]]
       end
    end
  end
end