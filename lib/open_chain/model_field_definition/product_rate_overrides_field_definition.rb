module OpenChain; module ModelFieldDefinition; module ProductRateOverrideFieldDefinition
  def add_product_rate_override_fields
    add_fields CoreModule::PRODUCT_RATE_OVERRIDE, [
      [1,:pro_key,:key,'Rate Override Key',{
        data_type: :string,
        read_only: true,
        qualified_field_name: "CONCAT(product_rate_overrides.origin_country_id,'-',product_rate_overrides.destination_country_id)",
        export_lambda: lambda {|obj| "#{obj.origin_country_id}-#{obj.destination_country_id}"}
      }],
      [2,:pro_rate,:rate,'Rate',{data_type: :decimal}],
      [3,:pro_notes,:notes,'Notes',{data_type: :text}],
      [4,:pro_updated_at, :updated_at, 'Last Changed', {data_type: :datetime,read_only:true}],
      [5,:pro_created_at, :created_at, 'Created Date', {data_type: :datetime,read_only:true}],
      [6,:pro_start_date, :start_date, 'Start Date', {data_type: :date}],
      [7,:pro_end_date, :end_date, 'End Date', {data_type: :date}],
      [8,:pro_product_id, :product_id, 'Product DB ID', {
        data_type: :integer,
        import_lambda: lambda {|obj,data|
          return "Cannot clear Product for Product Rate Override." if data.blank? && !obj.product_id.blank?
          return "Product not changed, update ignored." if obj.product_id.to_s == data.to_s
          if obj.product_id.blank?
            obj.product_id = data
            return "Product ID set to #{data}"
          else
            return "Cannot change Product for Product Rate Override, update ignored."
          end
        },
        required: true
      }],
      [9,:pro_active, :active, 'Is Active', {
        data_type: :boolean,
        read_only: true,
        export_lambda: lambda {|obj|
          obj.active?
        },
        qualified_field_name: "IF(#{ProductRateOverride.active_where_clause},1,0)"
      }],
    ]
    add_fields CoreModule::PRODUCT_RATE_OVERRIDE, make_country_arrays(100,'pro_origin','product_rate_overrides','origin_country','Origin')
    add_fields CoreModule::PRODUCT_RATE_OVERRIDE, make_country_arrays(200,'pro_destination','product_rate_overrides','destination_country','Destination')
  end
end; end; end
