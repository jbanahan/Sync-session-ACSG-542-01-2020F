module OpenChain; module ModelFieldGenerator; module VariantGenerator
  def make_variant_arrays(rank_start,uid_prefix,table_name)
    r = []
    r << [rank_start,"#{uid_prefix}_varuid".to_sym, :variant_identifier,"Variant Identifier", {
      read_only: true,
      data_type: :string,
      export_lambda: lambda {|line|
        return line.variant.variant_identifier if line.variant
        return nil
      },
      qualified_field_name: "(SELECT variant_identifier FROM variants WHERE variants.id = #{table_name}.variant_id)"
    }]
    r << [rank_start+1,"#{uid_prefix}_var_db_id".to_sym, :variant_id, "Variant DB ID", {
      data_type: :integer
    }]
    r
  end
end; end; end
