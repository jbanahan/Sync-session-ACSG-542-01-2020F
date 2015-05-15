require_relative 'model_field_definer'

module OpenChain
  module ModelFieldDefinition
    class BookingLineFieldDefiner < ModelFieldDefiner

      PREFIX = 'bkln'

      def fields
        [[1,:bkln_quantity, :quantity, "Quantity Booked", {type: :decimal}],
         [2,:bkln_order_number, :order_number, "Order", {
               type: :string,
               qualified_field_name: 'select order_number from orders where orders.id = booking_line.order_id'
           }],
         [3,:bkln_order_line_number, :order_line_number, "Order Line", {
               type: :integer,
               qualified_field_name: 'select line_number from order_lines where order_lines.id = booking_line.order_line_id'
           }]]
        .concat make_product_arrays(100,PREFIX,"booking_lines")
      end

      def core_module
        CoreModule::BOOKING_LINE
      end
    end

    module BookingLineFieldDefinition
      PREFIX = 'bkln'

      def _add_fields(fields)
        add_fields CoreModule::BOOKING_LINE, fields
      end

      def add_booking_line_fields
        _add_fields [[1,:bkln_quantity, :quantity, "Quantity Booked", {type: :decimal}],
                     [2,:bkln_order_number, :order_number, "Order", {
                           type: :string,
                           qualified_field_name: 'select order_number from orders where orders.id = booking_line.order_id'
                       }],
                     [3,:bkln_order_line_number, :order_line_number, "Order Line", {
                           type: :integer,
                           qualified_field_name: 'select line_number from order_lines where order_lines.id = booking_line.order_line_id'
                       }]]
        _add_fields make_product_arrays(100,PREFIX,"booking_lines")
      end


    end
  end
end