module OpenChain; module ModelFieldDefinition; module TariffFieldDefinition
  def add_tariff_fields
    add_fields CoreModule::TARIFF, [
      [4,:hts_line_number,:line_number,"HTS Row"],
      [5,:hts_view_sequence, :view_sequence, "View Sequence", {data_type: :string, history_ignore: true, user_accessible: false, read_only: true}],
      [6,:hts_chapter, :chapter, "Chapter", official_tariff_field_def("chapter")],
      [7,:hts_heading, :heading, "Heading", official_tariff_field_def("heading")],
      [8,:hts_sub_heading, :sub_heading, "Sub-Heading", official_tariff_field_def("sub_heading")],
      [9,:hts_full_description, :full_description, "Full Description", official_tariff_field_def("full_description")]
    ]
    add_fields CoreModule::TARIFF, make_hts_arrays(100,"hts")
  end


  def official_tariff_field_def field
    {
      data_type: :string, history_ignore: true, read_only: true,
      export_lambda: lambda { |obj| 
          value = ""
          if obj && !obj.hts_1.blank? && obj.classification && obj.classification.country_id
            t = OfficialTariff.where(country_id: obj.classification.country_id, hts_code: obj.hts_1).first
            value = t.public_send(field.to_sym).to_s if t
          end
          value
        },
      qualified_field_name: "(SELECT #{field} FROM official_tariffs ot_#{field} WHERE classifications.country_id = ot_#{field}.country_id AND tariff_records.hts_1 = ot_#{field}.hts_code)"
    }
  end
end; end; end
