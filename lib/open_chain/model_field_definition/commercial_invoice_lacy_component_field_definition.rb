module OpenChain; module ModelFieldDefinition; module CommercialInvoiceLaceyComponentFieldDefinition
  def add_commercial_invoice_lacey_fields
    add_fields CoreModule::COMMERCIAL_INVOICE_LACEY, [
      [1, :lcy_detailed_description, :detailed_description, "Detailed Description", datatype: :string],
      [2, :lcy_value, :value, "Value", datatype: :decimal, currency: :other],
      [3, :lcy_name, :name, "Name", datatype: :string],
      [4, :lcy_quantity, :quantity, "Quantity", datatype: :decimal],
      [5, :lcy_unit_of_measure, :unit_of_measure, "UOM", datatype: :string],
      [6, :lcy_genus, :genus, "Genus", datatype: :string],
      [7, :lcy_species, :species, "Species", datatype: :string],
      [8, :lcy_harvest_country, :harvested_from_country, "Harvest Country", datatype: :string],
      [9, :lcy_percent_recycled, :percent_recycled_material, "% Recycled Material", datatype: :decimal],
      [10, :lcy_container_numbers, :container_numbers, "Container Numbers", datatype: :string],
      [11, :lcy_line_number, :line_number, "Line Number", datatype: :integer]
    ]
  end
end; end; end