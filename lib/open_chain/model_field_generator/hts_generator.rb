module OpenChain; module ModelFieldGenerator; module HtsGenerator
  def make_hts_arrays(rank_start,uid_prefix)
    canada = Country.where(:iso_code=>"CA").first
    us = Country.where(:iso_code=>"US").first
    id_counter = rank_start
    r = []
    (1..3).each do |i|
      r << [id_counter,"#{uid_prefix}_hts_#{i}".to_sym, "hts_#{i}".to_sym,"HTS Code #{i}",{
        :export_lambda => lambda {|t|
          h = case i
            when 1 then t.hts_1
            when 2 then t.hts_2
            when 3 then t.hts_3
          end
          h.blank? ? "" : h.hts_format
        },
        :query_parameter_lambda => lambda {|t|
          case i
            when 1 then t.hts_1
            when 2 then t.hts_2
            when 3 then t.hts_3
          end
        },
        :process_query_result_lambda => lambda {|val|
          val.blank? ? "" : val.hts_format
        }
      }]
      id_counter += 1
      r << [id_counter,"#{uid_prefix}_hts_#{i}_schedb".to_sym,"schedule_b_#{i}".to_sym,"Schedule B Code #{i}"] if us && us.import_location #make sure us exists so test fixtures pass
      id_counter += 1
      r << [id_counter,"#{uid_prefix}_hts_#{i}_gr".to_sym, :general_rate,"#{i} - General Rate",{
        :import_lambda => lambda {|obj,data| return "General Duty Rate cannot be set by import, ignored."},
        :export_lambda => lambda {|t|
          ot = case i
            when 1 then t.hts_1_official_tariff
            when 2 then t.hts_2_official_tariff
            when 3 then t.hts_3_official_tariff
          end
          ot.nil? ? "" : ot.general_rate
        },
        :qualified_field_name => "(SELECT general_rate FROM official_tariffs WHERE official_tariffs.hts_code = tariff_records.hts_#{i} AND official_tariffs.country_id = (SELECT classifications.country_id FROM classifications WHERE classifications.id = tariff_records.classification_id LIMIT 1))",
        :data_type=>:string,
        :history_ignore=>true
      }]
      id_counter += 1
      r << [id_counter,"#{uid_prefix}_hts_#{i}_cr".to_sym, :common_rate,"#{i} - Common Rate",{
        :import_lambda => lambda {|obj,data| return "Common Duty Rate cannot be set by import, ignored."},
        :export_lambda => lambda {|t|
          ot = case i
            when 1 then t.hts_1_official_tariff
            when 2 then t.hts_2_official_tariff
            when 3 then t.hts_3_official_tariff
          end
          ot.nil? ? "" : ot.common_rate
        },
        :qualified_field_name => "(SELECT common_rate FROM official_tariffs WHERE official_tariffs.hts_code = tariff_records.hts_#{i} AND official_tariffs.country_id = (SELECT classifications.country_id FROM classifications WHERE classifications.id = tariff_records.classification_id LIMIT 1))",
        :data_type=>:string,
        :history_ignore=>true
      }]
      if canada && canada.import_location
        id_counter += 1
        r << [id_counter,"#{uid_prefix}_hts_#{i}_gpt".to_sym, :general_preferential_tariff_rate,"#{i} - GPT Rate",{
          :import_lambda => lambda {|obj,data| return "GPT Rate cannot be set by import, ignored."},
          :export_lambda => lambda {|t|
            ot = case i
              when 1 then t.hts_1_official_tariff
              when 2 then t.hts_2_official_tariff
              when 3 then t.hts_3_official_tariff
            end
            ot.nil? ? "" : ot.general_preferential_tariff_rate
          },
          :qualified_field_name => "(SELECT general_preferential_tariff_rate FROM official_tariffs WHERE official_tariffs.hts_code = tariff_records.hts_#{i} AND official_tariffs.country_id = (SELECT classifications.country_id FROM classifications WHERE classifications.id = tariff_records.classification_id LIMIT 1))",
          :data_type=>:string,
          :history_ignore=>true
        }]
      end
      if OfficialTariff.where("import_regulations is not null OR export_regulations is not null").count>0
        id_counter += 1
        r << [id_counter,"#{uid_prefix}_hts_#{i}_impregs".to_sym, :import_regulations,"#{i} - Import Regulations",{
          :import_lambda => lambda {|obj,data| return "HTS Import Regulations cannot be set by import, ignored."},
          :export_lambda => lambda {|t|
            ot = case i
              when 1 then t.hts_1_official_tariff
              when 2 then t.hts_2_official_tariff
              when 3 then t.hts_3_official_tariff
            end
            ot.nil? ? "" : ot.import_regulations
          },
          :qualified_field_name => "(SELECT import_regulations FROM official_tariffs WHERE official_tariffs.hts_code = tariff_records.hts_#{i} AND official_tariffs.country_id = (SELECT classifications.country_id FROM classifications WHERE classifications.id = tariff_records.classification_id LIMIT 1))",
          :data_type=>:string,
          :history_ignore=>true
        }]
        id_counter += 1
        r << [id_counter,"#{uid_prefix}_hts_#{i}_expregs".to_sym, :export_regulations,"#{i} - Export Regulations",{
          :import_lambda => lambda {|obj,data| return "HTS Export Regulations cannot be set by import, ignored."},
          :export_lambda => lambda {|t|
            ot = case i
              when 1 then t.hts_1_official_tariff
              when 2 then t.hts_2_official_tariff
              when 3 then t.hts_3_official_tariff
            end
            ot.nil? ? "" : ot.export_regulations
          },
          :qualified_field_name => "(SELECT export_regulations FROM official_tariffs WHERE official_tariffs.hts_code = tariff_records.hts_#{i} AND official_tariffs.country_id = (SELECT classifications.country_id FROM classifications WHERE classifications.id = tariff_records.classification_id LIMIT 1))",
          :data_type=>:string,
          :history_ignore=>true
        }]
      end
      id_counter += 1
      r << [id_counter,"#{uid_prefix}_hts_#{i}_qc".to_sym,:category,"#{i} - Quota Category",{
        :import_lambda => lambda {|obj,data| return "Quota Category cannot be set by import, ignored."},
        :export_lambda => lambda {|t|
          ot = case i
            when 1 then t.hts_1_official_tariff
            when 2 then t.hts_2_official_tariff
            when 3 then t.hts_3_official_tariff
          end
          return "" if ot.nil?
          q = ot.official_quota
          q.nil? ? "" : q.category
        },
        :qualified_field_name => "(SELECT category FROM official_quotas WHERE official_quotas.hts_code = tariff_records.hts_#{i} AND official_quotas.country_id = (SELECT classifications.country_id FROM classifications WHERE classifications.id = tariff_records.classification_id LIMIT 1))",
        :data_type=>:string,
        :history_ignore=>true
      }]
    end
    r
  end
end; end; end
