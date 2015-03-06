module OpenChain; module ModelFieldDefinition; module ClassificationFieldDefinition
  def add_classification_fields
    add_fields CoreModule::CLASSIFICATION, [
      [1,:class_comp_cnt, :comp_count, "Component Count", {
        :import_lambda => lambda {|obj,data| return "Component Count was ignored. (read only)"},
        :export_lambda => lambda {|obj| obj.tariff_records.size },
        :qualified_field_name => "(select count(id) from tariff_records tr where tr.classification_id = classifications.id)",
        :data_type => :integer,
        :history_ignore=>true
      }],
      [2,:class_updated_at, :updated_at, "Last Changed",{:data_type=>:datetime,:history_ignore=>true}]
    ]
    add_fields CoreModule::CLASSIFICATION, make_country_arrays(100,"class","classifications")
  end
end; end; end
