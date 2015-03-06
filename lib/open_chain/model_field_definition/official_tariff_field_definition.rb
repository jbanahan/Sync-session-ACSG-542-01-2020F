module OpenChain; module ModelFieldDefinition; module OfficialTariffFieldDefinition
  def add_official_tariff_fields
    add_fields CoreModule::OFFICIAL_TARIFF, [
      [1,:ot_hts_code,:hts_code,"HTS Code",{:data_type=>:string, :export_lambda => lambda {|ot| ot.hts_code.try(:hts_format)}}],
      [2,:ot_full_desc,:full_description,"Full Description",{:data_type=>:string}],
      [3,:ot_spec_rates,:special_rates,"Special Rates",{:data_type=>:string}],
      [4,:ot_gen_rate,:general_rate,"General Rate",{:data_type=>:string}],
      [5,:ot_chapter,:chapter,"Chapter",{:data_type=>:string}],
      [6,:ot_heading,:heading,"Heading",{:data_type=>:string}],
      [7,:ot_sub_heading,:sub_heading,"Sub-Heading",{:data_type=>:string}],
      [8,:ot_remaining,:remaining_description,"Remaining Description",{:data_type=>:string}],
      [9,:ot_ad_v,:add_valorem_rate,"Ad Valorem Rate",{:data_type=>:string}],
      [10,:ot_per_u,:per_unit_rate,"Per Unit Rate",{:data_type=>:string}],
      [11,:ot_calc_meth,:calculation_method,"Calculation Method",{:data_type=>:string}],
      [12,:ot_mfn,:most_favored_nation_rate,"MFN Rate",{:data_type=>:string}],
      [13,:ot_gpt,:general_preferential_tariff_rate,"GPT Rate",{:data_type=>:string}],
      [14,:ot_erga_omnes_rate,:erga_omnes_rate,"Erga Omnes Rate",{:data_type=>:string}],
      [15,:ot_uom,:unit_of_measure,"Unit of Measure",{:data_type=>:string}],
      [16,:ot_col_2,:column_2_rate,"Column 2 Rate",{:data_type=>:string}],
      [17,:ot_import_regs,:import_regulations,"Import Regulations",{:data_type=>:string}],
      [18,:ot_export_regs,:export_regulations,"Export Regulations",{:data_type=>:string}],
      [19,:ot_common_rate,:common_rate,"Common Rate",{:data_type=>:string}],
      [20,:ot_chapter_number, :chapter_number,"Chapter Number",{:data_type=>:string,
          :import_lambda => lambda { |ent, data|
            "Chapter Number ignored. (read only)"
          },
          :export_lambda => lambda { |obj|
            obj.hts_code[0,2]
          },
          :qualified_field_name => "LEFT(hts_code,2)"
        }
      ]
    ]
    add_fields CoreModule::OFFICIAL_TARIFF, make_country_arrays(100,"ot","official_tariffs")
  end
end; end; end
