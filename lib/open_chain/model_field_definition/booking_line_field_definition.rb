module OpenChain
  module ModelFieldDefinition
    module BookingLineFieldDefinition
      PREFIX = 'bkln'

      def _add_fields(fields)
        add_fields CoreModule::BOOKING_LINE, fields
      end

      def add_booking_line_fields
        _add_fields [[1,:bkln_quantity, :quantity, "Quantity Booked", {type: :decimal}]]
        _add_fields make_product_arrays(100,PREFIX,"booking_lines")
      end


    end
  end
end