module OpenChain
  module ModelFieldDefinition
    module BookingLineFieldDefinition

      def add_booking_line_fields
        add_fields CoreModule::BOOKING_LINE, [
         [0, :bkln_line_number, :line_number, "Line Number", {:type=>:integer}],
         [0, :bkln_quantity, :quantity, "Quantity Booked", {:type=>:decimal, :description=>"Quantity Booked"}],
         [0, :bkln_gross_kgs, :gross_kgs, "Gross Weights (KGS)", {:type=>:integer, :description=>"Gross Weights (KGS)"}],
         [0, :bkln_cbms, :cbms, "CBMS", {:type=>:integer, :description=>"CBMS"}],
         [0, :bkln_carton_qty, :carton_qty, "Carton Quantity", {:type=>:integer, :description=>"Carton Quantity"}],
         [12,:bkln_carton_set_uid,:carton_set_id,"Carton Set Unique ID",
          {data_type: :integer,
           import_lambda: lambda {|sl,id|
             return "#{ModelField.find_by_uid(:bkln_carton_set_uid).label} was blank." if id.blank?
             cs = CartonSet.find_by_id id
             return "Carton Set with ID #{id} not found. Ignored." unless cs
             return "#{ModelField.find_by_uid(:bkln_carton_set_uid).label} is not part of this shipment and was ignored." unless cs.shipment_id == sl.shipment_id
             sl.carton_set_id = cs.id
             "#{ModelField.find_by_uid(:bkln_carton_set_uid).label} set to #{cs.id}."
           }
          }]]
          add_fields CoreModule::BOOKING_LINE, make_product_arrays(100,'bkln',CoreModule::BOOKING_LINE.table_name)
       end
    end
  end
end