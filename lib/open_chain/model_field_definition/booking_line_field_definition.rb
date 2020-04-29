module OpenChain; module ModelFieldDefinition; module BookingLineFieldDefinition

  def core_module
    CoreModule::BOOKING_LINE
  end

  def add_booking_line_fields
    add_fields core_module, [
     [1, :bkln_line_number, :line_number, "Line Number", {:data_type=>:integer}],
     [2, :bkln_quantity, :quantity, "Booked Quantity", {:data_type=>:decimal}],
     [3, :bkln_gross_kgs, :gross_kgs, "Gross Weights (KGS)", {:data_type=>:decimal}],
     [4, :bkln_cbms, :cbms, "CBMS", {:data_type=>:decimal}],
     [5, :bkln_carton_qty, :carton_qty, "Carton Quantity", {:data_type=>:integer}],
     [6, :bkln_carton_set_uid, :carton_set_id, "Carton Set Unique ID",
      {data_type: :integer, user_accessible: false,
       import_lambda: lambda {|sl, id|
         return "#{ModelField.find_by_uid(:bkln_carton_set_uid).label} was blank." if id.blank?
         cs = CartonSet.find_by_id id
         return "Carton Set with ID #{id} not found. Ignored." unless cs
         return "#{ModelField.find_by_uid(:bkln_carton_set_uid).label} is not part of this shipment and was ignored." unless cs.shipment_id == sl.shipment_id
         sl.carton_set_id = cs.id
         "#{ModelField.find_by_uid(:bkln_carton_set_uid).label} set to #{cs.id}."
       }
      }],
     [7, :bkln_order_and_line_number, :order_and_line_number, "Order and Line Number", {
          data_type: :string,
          read_only: true,
          export_lambda: lambda { |bl| bl.customer_order_and_line_number },
          qualified_field_name: "(SELECT CONCAT_WS(' - ', IF((orders.customer_order_number IS NULL OR LENGTH(TRIM(orders.customer_order_number)) = 0), orders.order_number, orders.customer_order_number), order_lines.line_number)
FROM order_lines
INNER JOIN orders ON orders.id = order_lines.order_id
WHERE booking_lines.order_id = order_lines.order_id AND booking_lines.order_line_id = order_lines.id)"
       }],
     [8, :bkln_order_id, :order_id, "Order ID", {
           data_type: :integer, user_accessible: false,
           export_lambda: lambda {|bl| bl.order_id ? bl.order_id : bl.order_line.try(:order).try(:id) }
       }],
     [9, :bkln_puid, :unique_identifier, "Product Unique ID", {
                    :import_lambda => lambda {|detail, data|
                      return "Product not changed." if detail.product && detail.product.unique_identifier==data
                      p = Product.where(:unique_identifier=>data).first
                      return "Product not found with unique identifier #{data}" if p.nil?
                      detail.product = p
                      return "Product set to #{data}"
                    },
                    :export_lambda => lambda {|detail|
                      product = detail.product || detail.order_line.try(:product)
                      product.try(:unique_identifier)
                    },
                    :qualified_field_name => "(SELECT products.unique_identifier FROM products WHERE products.id = booking_lines.product_id)"
                }],
     [10, :bkln_pname, :name, "Product Name", {
       :import_lambda => lambda {|detail, data|
        "Product name cannot be set by import."
       },
       :export_lambda => lambda {|detail|
         product = detail.product || detail.order_line.try(:product)
         product.try(:name)
       },
       :qualified_field_name => "(SELECT products.name FROM products WHERE products.id = booking_lines.product_id)",
       :history_ignore => true,
       :read_only => true
     }],
     [11, :bkln_prod_id, :id, "Product ID", {user_accessible: false,
       history_ignore: true,
       :import_lambda => lambda {|detail, data, user|
         product_id = data.to_i
         if detail.product_id != product_id && !(prod = Product.where(id: product_id).first).nil?
           detail.product  = prod if prod.can_view?(user)
         end
         ""
        }
      }],
      [12, :bkln_container_size, :container_size, "Container Size", {data_type: :string}],
      [13, :bkln_order_line_id, :order_line_id, "Order Line DB ID", {data_type: :integer, user_accessible: false}],
      [14, :bkln_product_db_id, :product_id, "Product DB ID", {data_type: :integer, user_accessible: false}],
      [15, :bkln_order_number, :booked_order_number, "Order Number", {data_type: :string, read_only: true,
          export_lambda: lambda {|detail|
            cust_order_number = detail.order.try(:customer_order_number)
            cust_order_number.blank? ? detail.order.try(:order_number) : cust_order_number
          },
          qualified_field_name: "(SELECT IFNULL(orders.customer_order_number, orders.order_number) FROM orders WHERE booking_lines.order_id = orders.id LIMIT 1)"}],
      [16, :bkln_order_line_number, :order_line_number, "Order Line Number", {data_type: :integer, read_only: true,
          export_lambda: lambda {|detail| detail.order_line.try(:line_number)},
          qualified_field_name: "(SELECT line_number FROM order_lines AS booking_order_line WHERE booking_order_line.id = booking_lines.order_line_id)"}],
     [17, :bkln_order_line_quantity, :order_line_quantity, "Order Quantity", {data_type: :decimal, read_only: true,
         export_lambda: lambda {|detail| detail.order_line.try(:quantity)},
         qualified_field_name: "(SELECT quantity FROM order_lines as booking_order_line WHERE booking_order_line.id = booking_lines.order_line_id)"}],
     [18, :bkln_quantity_diff, :order_line_quantity_diff, "Percentage Booked", {data_type: :decimal, read_only: true,
         export_lambda: lambda {|detail|
             if detail.order_line.try(:quantity).try(:nonzero?) && detail.try(:quantity)
               (detail.quantity / detail.order_line.quantity) * 100
             else
               nil
             end
         },
         qualified_field_name: "(SELECT ROUND(IFNULL((booking_lines.quantity / order_lines.quantity) * 100, 0), 2)
FROM
order_lines
WHERE
order_lines.id = booking_lines.order_line_id)"}],
      [19, :bkln_summed_order_line_quantity, :order_line_summed_quantity, "Product Summed Order Quantity", {data_type: :decimal, read_only: true,
        import_lambda: lambda {|obj, data| "Product Summed Order Quantity ignored. (read only)"},
        export_lambda: lambda {|detail| detail.product_summed_order_quantity},
        qualified_field_name: order_line_summed_quantity_qry
       }],
      [20, :bkln_quantity_diff_by_product, :order_line_quantity_diff_by_product, "Percentage Booked By Product", {data_type: :decimal, read_only: true,
        import_lambda: lambda {|obj, data| "Percentage Booked By Product ignored. (read only)"},
        export_lambda: lambda {|detail|
            summed_quantity = detail.product_summed_order_quantity
            if summed_quantity.try(:nonzero?) && detail.try(:quantity)
              (detail.quantity / summed_quantity) * 100
            else
              nil
            end
          },
        qualified_field_name: "(SELECT ROUND(IFNULL((booking_lines.quantity / #{order_line_summed_quantity_qry}) * 100, 0), 2))"
        }]
    ]
    add_fields CoreModule::BOOKING_LINE, make_variant_arrays(100, 'bkln', 'booking_lines')
  end

  def order_line_summed_quantity_qry
    <<-SQL
       (SELECT SUM(bol.quantity)
        FROM order_lines bol
        WHERE bol.product_id = booking_lines.product_id AND bol.order_id = booking_lines.order_id)
    SQL
  end

end; end; end
