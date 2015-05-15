require_relative 'model_field_definer'

module OpenChain
  module ModelFieldDefinition
    class BookingLineFieldDefiner < ModelFieldDefiner
      def prefix; 'bkln' end

      def fields
        [field(:line_number, {type: :integer}),
         field(:quantity, {description:"Quantity Booked", type: :decimal}),
         field( :order_number, {
               description: 'Order',
               qualified_field_name: 'select order_number from orders where orders.id = booking_line.order_id'
           }),
         field(:order_line_number, {description: "Order Line",
               type: :integer,
               qualified_field_name: 'select line_number from order_lines where order_lines.id = booking_line.order_line_id'
           })]
        .concat make_product_arrays(100,prefix,core_module.table_name)
      end

      def core_module
        CoreModule::BOOKING_LINE
      end
    end
  end
end