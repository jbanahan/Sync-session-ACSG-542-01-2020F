require_relative 'model_field_definer'

module OpenChain
  module ModelFieldDefinition
    class BookingLineFieldDefiner < ModelFieldDefiner
      def prefix; 'bkln' end

      def fields
        [field(:line_number, {type: :integer}),
         field(:quantity, {description:"Quantity Booked", type: :decimal}),
         field(:gross_kgs,{description: "Gross Weights (KGS)", type: :decimal}),
         field(:cbms, {description:"CBMS", type: :decimal}),
         field(:carton_qty, { description: "Carton Quantity", type: :integer}),
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
        .concat make_product_arrays(100,prefix,core_module.table_name)
      end

      def core_module
        CoreModule::BOOKING_LINE
      end
    end
  end
end