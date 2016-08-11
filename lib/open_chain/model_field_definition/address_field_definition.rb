module OpenChain; module ModelFieldDefinition; module AddressFieldDefinition

  def add_address_fields
    add_fields CoreModule::ADDRESS, [
      [1, :add_syscode, :system_code, 'System Code', {data_type: :string}],
      [2, :add_name, :name, 'Name', {data_type: :string}],
      [3, :add_line_1, :line_1, 'Line 1', {data_type: :string}],
      [4, :add_line_2, :line_2, 'Line 2', {data_type: :string}],
      [5, :add_line_3, :line_3, 'Line 3', {data_type: :string}],
      [6, :add_city, :city, 'City', {data_type: :string}],
      [7, :add_state, :state, 'State', {data_type: :string}],
      [8, :add_postal_code, :postal_code, 'Postal Code', {data_type: :string}],
      [9, :add_created_at, :created_at, 'Create Date', {data_type: :datetime,
        read_only:true}],
      [10, :add_updated_at, :updated_at, 'Update Date', {data_type: :datetime,
        read_only:true}],
      [11, :add_shipping, :shipping, 'Shipping Address', {data_type: :boolean}],
      [12, :add_phone_number, :phone_number, 'Phone Number', {data_type: :string}],
      [13, :add_fax_number, :fax_number, 'Fax Number', {data_type: :string}],
      [14, :add_full_address, :full_address, "Full Address", {
         data_type: :string,
         read_only:true,
         export_lambda: lambda {|obj| obj.full_address},
         qualified_field_name: "(CONCAT_WS(' ', IFNULL(line_1, ''), IFNULL(line_2, ''), IFNULL(line_3, ''),'\n', IFNULL(city, ''), IFNULL(state, ''), IFNULL(postal_code, ''),'\n',IFNULL((select iso_code from countries where addresses.country_id = countries.id),'')))"
       }],
       [15, :add_comp_db_id, :company_id, 'Company DB ID', {data_type: :integer}]
    ]
    add_fields CoreModule::ADDRESS, make_country_arrays(100,'add','addresses')
    add_fields CoreModule::ADDRESS, make_company_arrays(200,'add','addresses','comp','Company','company')
  end
end; end; end
