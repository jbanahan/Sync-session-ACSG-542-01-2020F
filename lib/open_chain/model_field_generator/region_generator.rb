module OpenChain; module ModelFieldGenerator; module RegionGenerator
  
  #Get the unique ID to be used for a given region and model field type
  def uid_for_region region, type
    "*r_#{region.id}_#{type}"
  end

  def make_region_fields
    model_fields = []
    Region.all.each do |r|
      mf = ModelField.new(next_index_number(CoreModule::PRODUCT),
        "*r_#{r.id}_class_count".to_sym,
        CoreModule::PRODUCT,
        "*r_#{r.id}_class_count".to_sym, {
          :label_override => "Classification Count - #{r.name}",
          :import_lambda => lambda {|p,d| "Classification count ignored."},
          :export_lambda => lambda {|p|
            good_country_ids = Region.find(r.id).countries.collect {|c| c.id}
            cnt = 0
            p.classifications.each do |cl|
              cnt += 1 if good_country_ids.include?(cl.country_id) && cl.classified?
            end
            cnt
          },
          :data_type => :integer,
          :history_ignore => true,
          :qualified_field_name => "(
select count(*) from classifications
inner join countries_regions on countries_regions.region_id = #{r.id} and countries_regions.country_id = classifications.country_id
where (select count(*) from tariff_records where tariff_records.classification_id = classifications.id and length(tariff_records.hts_1)>0) > 0
and classifications.product_id = products.id
)"
        }
      )
      model_fields << mf
    end
    model_fields
  end
end; end; end;
