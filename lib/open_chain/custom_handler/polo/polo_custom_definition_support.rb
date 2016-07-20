require 'open_chain/custom_handler/custom_definition_support'
module OpenChain
  module CustomHandler
    module Polo
      module PoloCustomDefinitionSupport
        extend ActiveSupport::Concern

        CUSTOM_DEFINITION_INSTRUCTIONS = {
          :ord_division => {label: "Merchandise Division", data_type: :string, module_type: "Order"},
          :ord_line_ex_factory_date => {label: "Planned Ex-Factory", data_type: :date, module_type: "OrderLine"},
          :ord_line_ship_mode => {label: "Ship Mode", data_type: :string, module_type: "OrderLine"},
          :ord_line_board_number => {label: "Board Number", data_type: :string, module_type: "OrderLine"},
          :bartho_customer_id=>{:label=>"Barthco Customer ID", :data_type=>:string, :module_type=>'Product'},
          :season=>{:label=>"Season", :data_type => :string, :module_type=>'Product'},
          :test_style=>{:label=>"Test Style", :data_type=>:string, :module_type=>'Product'},
          :set_type=>{:label=>"Set Type", :data_type=>:string, :module_type=>'Classification'},
          :merch_division=>{:label=>'Merch Div Desc', :data_type=>:string, :module_type=>'Product'},
          :csm_numbers => {:label=>'CSM Number', :data_type=>:text, :module_type=>'Product'},
          :fiber_content => {:label=>'Fiber Content %s', :data_type=>:string, :module_type=>'Product'},
          :fabric_type_1 => {label: 'Fabric Type - 1', data_type: :string, module_type: "Product"},
          :fabric_1 => {label: 'Fabric - 1', data_type: :string, module_type: "Product"},
          :fabric_percent_1 => {label: 'Fabric % - 1', data_type: :decimal, module_type: "Product"},
          :fabric_type_2 => {label: 'Fabric Type - 2', data_type: :string, module_type: "Product"},
          :fabric_2 => {label: 'Fabric - 2', data_type: :string, module_type: "Product"},
          :fabric_percent_2 => {label: 'Fabric % - 2', data_type: :decimal, module_type: "Product"},
          :fabric_type_3 => {label: 'Fabric Type - 3', data_type: :string, module_type: "Product"},
          :fabric_3 => {label: 'Fabric - 3', data_type: :string, module_type: "Product"},
          :fabric_percent_3 => {label: 'Fabric % - 3', data_type: :decimal, module_type: "Product"},
          :fabric_type_4 => {label: 'Fabric Type - 4', data_type: :string, module_type: "Product"},
          :fabric_4 => {label: 'Fabric - 4', data_type: :string, module_type: "Product"},
          :fabric_percent_4 => {label: 'Fabric % - 4', data_type: :decimal, module_type: "Product"},
          :fabric_type_5 => {label: 'Fabric Type - 5', data_type: :string, module_type: "Product"},
          :fabric_5 => {label: 'Fabric - 5', data_type: :string, module_type: "Product"},
          :fabric_percent_5 => {label: 'Fabric % - 5', data_type: :decimal, module_type: "Product"},
          :fabric_type_6 => {label: 'Fabric Type - 6', data_type: :string, module_type: "Product"},
          :fabric_6 => {label: 'Fabric - 6', data_type: :string, module_type: "Product"},
          :fabric_percent_6 => {label: 'Fabric % - 6', data_type: :decimal, module_type: "Product"},
          :fabric_type_7 => {label: 'Fabric Type - 7', data_type: :string, module_type: "Product"},
          :fabric_7 => {label: 'Fabric - 7', data_type: :string, module_type: "Product"},
          :fabric_percent_7 => {label: 'Fabric % - 7', data_type: :decimal, module_type: "Product"},
          :fabric_type_8 => {label: 'Fabric Type - 8', data_type: :string, module_type: "Product"},
          :fabric_8 => {label: 'Fabric - 8', data_type: :string, module_type: "Product"},
          :fabric_percent_8 => {label: 'Fabric % - 8', data_type: :decimal, module_type: "Product"},
          :fabric_type_9 => {label: 'Fabric Type - 9', data_type: :string, module_type: "Product"},
          :fabric_9 => {label: 'Fabric - 9', data_type: :string, module_type: "Product"},
          :fabric_percent_9 => {label: 'Fabric % - 9', data_type: :decimal, module_type: "Product"},
          :fabric_type_10 => {label: 'Fabric Type - 10', data_type: :string, module_type: "Product"},
          :fabric_10 => {label: 'Fabric - 10', data_type: :string, module_type: "Product"},
          :fabric_percent_10 => {label: 'Fabric % - 10', data_type: :decimal, module_type: "Product"},
          :fabric_type_11 => {label: 'Fabric Type - 11', data_type: :string, module_type: "Product"},
          :fabric_11 => {label: 'Fabric - 11', data_type: :string, module_type: "Product"},
          :fabric_percent_11 => {label: 'Fabric % - 11', data_type: :decimal, module_type: "Product"},
          :fabric_type_12 => {label: 'Fabric Type - 12', data_type: :string, module_type: "Product"},
          :fabric_12 => {label: 'Fabric - 12', data_type: :string, module_type: "Product"},
          :fabric_percent_12 => {label: 'Fabric % - 12', data_type: :decimal, module_type: "Product"},
          :fabric_type_13 => {label: 'Fabric Type - 13', data_type: :string, module_type: "Product"},
          :fabric_13 => {label: 'Fabric - 13', data_type: :string, module_type: "Product"},
          :fabric_percent_13 => {label: 'Fabric % - 13', data_type: :decimal, module_type: "Product"},
          :fabric_type_14 => {label: 'Fabric Type - 14', data_type: :string, module_type: "Product"},
          :fabric_14 => {label: 'Fabric - 14', data_type: :string, module_type: "Product"},
          :fabric_percent_14 => {label: 'Fabric % - 14', data_type: :decimal, module_type: "Product"},
          :fabric_type_15 => {label: 'Fabric Type - 15', data_type: :string, module_type: "Product"},
          :fabric_15 => {label: 'Fabric - 15', data_type: :string, module_type: "Product"},
          :fabric_percent_15 => {label: 'Fabric % - 15', data_type: :decimal, module_type: "Product"},
          :clean_fiber_content => {label: 'Clean Fiber Content', data_type: :string, module_type: "Product", read_only: true},
          :msl_fiber_failure => {label: "MSL Fiber Failure", data_type: :boolean, module_type: "Product"},
          :length_cm => {label: "Length (cm)", data_type: :decimal, module_type: "Product"},
          :width_cm => {label: "Width (cm)", data_type: :decimal, module_type: "Product"},
          :height_cm => {label: "Height (cm)", data_type: :decimal, module_type: "Product"},
          :msl_receive_date => {label: "MSL+ Receive Date", data_type: :date, module_type: "Product"},
          :msl_us_class => {label: "MSL+ US Class", data_type: :string, module_type: "Product"},
          :msl_us_brand => {label: "MSL+ US Brand", data_type: :string, module_type: "Product"},
          :msl_us_sub_brand => {label: "MSL+ US Sub Brand", data_type: :string, module_type: "Product"},
          :msl_model_desc => {label: "MSL+ Model Description", data_type: :string, module_type: "Product"},
          :msl_hts_desc => {label: "MSL+ HTS Description", data_type: :string, module_type: "Product"},
          :msl_hts_desc_2 => {label: "MSL+ HTS Description 2", data_type: :string, module_type: "Product"},
          :msl_hts_desc_3 => {label: "MSL+ HTS Description 3", data_type: :string, module_type: "Product"},
          :ax_subclass => {label: "AX Subclass", data_type: :string, module_type: "Product"},
          :msl_item_desc => {label: "MSL+ Item Description", data_type: :string, module_type: "Product"},
          :msl_us_season => {label: "MSL+ US Season", data_type: :string, module_type: "Product"},
          :msl_gcc_desc => {label: "GCC Description", data_type: :string, module_type: "Product"},
          :msl_board_number => {label: "Board Number", data_type: :string, module_type: "Product"},
          :knit_woven => {label: "Knit / Woven?", data_type: :string, module_type: "Product"},
          :common_name_1 => {label: "Common Name 1", data_type: :string, module_type: "Product"},
          :common_name_2 => {label: "Common Name 2", data_type: :string, module_type: "Product"},
          :common_name_3 => {label: "Common Name 3", data_type: :string, module_type: "Product"},
          :scientific_name_1 => {label: "Scientific Name 1", data_type: :string, module_type: "Product"},
          :scientific_name_2 => {label: "Scientific Name 2", data_type: :string, module_type: "Product"},
          :scientific_name_3 => {label: "Scientific Name 3", data_type: :string, module_type: "Product"},
          :fish_wildlife_origin_1 => {label: "F&W Origin 1", data_type: :string, module_type: "Product"},
          :fish_wildlife_origin_2 => {label: "F&W Origin 2", data_type: :string, module_type: "Product"},
          :fish_wildlife_origin_3 => {label: "F&W Origin 3", data_type: :string, module_type: "Product"},
          :fish_wildlife_source_1 => {label: "F&W Source 1", data_type: :string, module_type: "Product"},
          :fish_wildlife_source_2 => {label: "F&W Source 2", data_type: :string, module_type: "Product"},
          :fish_wildlife_source_3 => {label: "F&W Source 3", data_type: :string, module_type: "Product"},
          :origin_wildlife => {label: "Origin of Wildlife", data_type: :string, module_type: "Product"},
          :semi_precious => {label: "Semi-Precious", data_type: :boolean, module_type: "Product"},
          :semi_precious_type => {label: "Type of Semi-Precious", data_type: :string, module_type: "Product"},
          :cites => {label: "CITES", data_type: :boolean, module_type: "Product"},
          :fish_wildlife => {label: "Fish & Wildlife", data_type: :boolean, module_type: "Product"},
          :msl_fiber_status => {label: "MSL Fiber Status", data_type: :string, module_type: "Product"}
        }

        included do |base|
          base.extend(::OpenChain::CustomHandler::CustomDefinitionSupport)
        end
        
        module ClassMethods
          def prep_custom_definitions fields
            prep_custom_defs fields, CUSTOM_DEFINITION_INSTRUCTIONS
          end
        end
      end
    end
  end
end
