module OpenChain; module ModelFieldDefinition; module TariffFieldDefinition
  def add_tariff_fields
    add_fields CoreModule::TARIFF, [
      [4,:hts_line_number,:line_number,"HTS Row"],
      [5,:hts_view_sequence, :view_sequence, "View Sequence", {data_type: :string, history_ignore: true, user_accessible: false}]
    ]
    add_fields CoreModule::TARIFF, make_hts_arrays(100,"hts")
  end
end; end; end
