module OpenChain; module ModelFieldDefinition; module TradePreferenceProgramFieldDefinition
  def add_trade_preference_program_fields
    add_fields CoreModule::TRADE_PREFERENCE_PROGRAM, [
      [1, :tpp_tariff_adjustment_percentage, :tariff_adjustment_percentage, "Tariff Adjustment Percentage", {
        data_type: :decimal
      }],
      [2, :tpp_name, :name, 'Name', {data_type: :string}],
      [3, :tpp_updated_at, :updated_at, 'Last Changed', {data_type: :datetime, read_only:true}],
      [4, :tpp_created_at, :created_at, 'Created Date', {data_type: :datetime, read_only:true}],
      [5, :tpp_tariff_identifier, :tariff_identifier, 'Tariff Identifier', {data_type: :string}]
    ]
    add_fields CoreModule::TRADE_PREFERENCE_PROGRAM, make_country_arrays(100, 'tpp_origin', 'trade_preference_programs', 'origin_country', association_title: 'Origin')
    add_fields CoreModule::TRADE_PREFERENCE_PROGRAM, make_country_arrays(200, 'tpp_destination', 'trade_preference_programs', 'destination_country', association_title: 'Destination')
  end
end; end; end
