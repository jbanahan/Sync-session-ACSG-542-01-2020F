require_relative 'model_field_definer'

module OpenChain
  module ModelFieldDefinition
    class BookingLineFieldDefiner < ModelFieldDefiner
      def prefix; 'bkln' end

      def fields
        [default_field(:quantity, {description:"Quantity Booked", type: :decimal}),
         default_field( :order_number, {
               description: 'Order',
               qualified_field_name: 'select order_number from orders where orders.id = booking_line.order_id'
           }),
         default_field(:order_line_number, {description: "Order Line",
               type: :integer,
               qualified_field_name: 'select line_number from order_lines where order_lines.id = booking_line.order_line_id'
           })]
        .concat make_product_arrays(100,prefix,"booking_lines")
      end

      def core_module
        CoreModule::BOOKING_LINE
      end
    end
  end
end