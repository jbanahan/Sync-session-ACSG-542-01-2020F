module OpenChain; module ModelFieldDefinition; module TradeLaneFieldDefinition
  def add_trade_lane_fields
    add_fields CoreModule::TRADE_LANE, [
      [1, :lane_tariff_adjustment_percentage, :tariff_adjustment_percentage, "Tariff Adjustment Percentage", {
        data_type: :decimal
      }],
      [2, :lane_notes, :notes, 'Notes', {
        data_type: :text
      }],
      [3, :lane_updated_at, :updated_at, 'Last Changed', {data_type: :datetime,read_only:true}],
      [4, :lane_created_at, :created_at, 'Created Date', {data_type: :datetime,read_only:true}]
    ]
    add_fields CoreModule::TRADE_LANE, make_country_arrays(100,'lane_origin','trade_lanes','origin_country', association_title: 'Origin')
    add_fields CoreModule::TRADE_LANE, make_country_arrays(200,'lane_destination','trade_lanes','destination_country', association_title: 'Destination')
  end
end; end; end
