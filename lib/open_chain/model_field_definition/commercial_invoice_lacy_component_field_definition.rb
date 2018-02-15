module OpenChain; module ModelFieldDefinition; module CommercialInvoiceLaceyComponentFieldDefinition
  def add_commercial_invoice_lacey_fields
    add_fields CoreModule::COMMERCIAL_INVOICE_LACEY, [
      [1, :lcy_detailed_description, :detailed_description, "Detailed Description", data_type: :string],
      [2, :lcy_value, :value, "Value", data_type: :decimal, currency: :other],
      [3, :lcy_name, :name, "Name", data_type: :string],
      [4, :lcy_quantity, :quantity, "Quantity", data_type: :decimal],
      [5, :lcy_unit_of_measure, :unit_of_measure, "UOM", data_type: :string],
      [6, :lcy_genus, :genus, "Genus", data_type: :string],
      [7, :lcy_species, :species, "Species", data_type: :string],
      [8, :lcy_harvest_country, :harvested_from_country, "Harvest Country", data_type: :string],
      [9, :lcy_percent_recycled, :percent_recycled_material, "% Recycled Material", data_type: :decimal],
      [10, :lcy_container_numbers, :container_numbers, "Container Numbers", data_type: :string],
      [11, :lcy_line_number, :line_number, "Line Number", data_type: :integer]
    ]
  end
end; end; end
