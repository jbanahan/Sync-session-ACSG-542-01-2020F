module OpenChain; module ModelFieldDefinition; module VariantFieldDefinition
  def add_variant_fields
    add_fields CoreModule::VARIANT, [
      [1, :var_identifier, :variant_identifier, "Variant Identifier"],
      [2, :var_updated_at, :updated_at, "Last Changed", {:data_type=>:datetime, :history_ignore=>true, :read_only=>true}],
      [3, :var_created_at, :created_at, "Created Date", {:data_type=>:datetime, :history_ignore=>true, :read_only=>true}],
      [4, :var_product_id, :product_id, "Product ID", {data_type: :integer, read_only: true}]
    ]
  end
end; end; end
