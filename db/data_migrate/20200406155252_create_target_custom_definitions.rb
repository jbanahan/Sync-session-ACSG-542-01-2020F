require 'open_chain/custom_handler/target/target_custom_definition_support'

class CreateTargetCustomDefinitions < ActiveRecord::Migration
  include OpenChain::CustomHandler::Target::TargetCustomDefinitionSupport

  def up
    return unless MasterSetup.get.custom_feature?("Target")

    create_custom_definitions
    disable_product_type
  end

  def disable_product_type
    FieldValidatorRule.create! module_type: "Product", model_field_uid: "prod_ent_type", disabled: true
  end

  def enable_product_type
    FieldValidatorRule.where(model_field_uid: "prod_ent_type", disabled: true).each(&:destroy)
  end

  def create_custom_definitions
    # Create custom definitions and then update their screen ranks.
    ModelField.disable_reloads do
      cdefs[:prod_part_number].update! rank: 10
      cdefs[:prod_vendor_order_point].update! rank: 20
      cdefs[:prod_vendor_style].update! rank: 30
      cdefs[:prod_type].update! rank: 40
      cdefs[:prod_required_documents].update! rank: 50

      cdefs[:prod_aphis].update! rank: 60
      cdefs[:prod_usda].update! rank: 70
      cdefs[:prod_epa].update! rank: 80
      cdefs[:prod_cps].update! rank: 90
      cdefs[:prod_tsca].update! rank: 100
      cdefs[:prod_long_description].update! rank: 1000

      cdefs[:tar_country_of_origin].update! rank: 110
      cdefs[:tar_spi_primary].update! rank: 120
      cdefs[:tar_xvv].update! rank: 130
      cdefs[:tar_component_description].update! rank: 140

      cdefs[:tar_cvd_case].update! rank: 150
      cdefs[:tar_add_case].update! rank: 160

      cdefs[:tar_dot_flag].update! rank: 170
      cdefs[:tar_dot_program].update! rank: 180
      cdefs[:tar_dot_box_number].update! rank: 190

      cdefs[:tar_fda_flag].update! rank: 200
      cdefs[:tar_fda_product_code].update! rank: 210
      cdefs[:tar_fda_cargo_status].update! rank: 220
      cdefs[:tar_fda_food].update! rank: 230
      cdefs[:tar_fda_affirmation_code_1].update! rank: 240
      cdefs[:tar_fda_affirmation_qualifier_1].update! rank: 250
      cdefs[:tar_fda_affirmation_code_2].update! rank: 260
      cdefs[:tar_fda_affirmation_qualifier_2].update! rank: 270
      cdefs[:tar_fda_affirmation_code_3].update! rank: 280
      cdefs[:tar_fda_affirmation_qualifier_3].update! rank: 290
      cdefs[:tar_fda_affirmation_code_4].update! rank: 300
      cdefs[:tar_fda_affirmation_qualifier_4].update! rank: 310
      cdefs[:tar_fda_affirmation_code_5].update! rank: 320
      cdefs[:tar_fda_affirmation_qualifier_5].update! rank: 330
      cdefs[:tar_fda_affirmation_code_6].update! rank: 340
      cdefs[:tar_fda_affirmation_qualifier_6].update! rank: 350
      cdefs[:tar_fda_affirmation_code_7].update! rank: 360
      cdefs[:tar_fda_affirmation_qualifier_7].update! rank: 370

      cdefs[:tar_lacey_flag].update! rank: 380
      cdefs[:tar_lacey_common_name_1].update! rank: 390
      cdefs[:tar_lacey_genus_1].update! rank: 400
      cdefs[:tar_lacey_species_1].update! rank: 410
      cdefs[:tar_lacey_country_1].update! rank: 420
      cdefs[:tar_lacey_quantity_1].update! rank: 430
      cdefs[:tar_lacey_uom_1].update! rank: 440
      cdefs[:tar_lacey_recycled_1].update! rank: 450
      cdefs[:tar_lacey_common_name_2].update! rank: 460
      cdefs[:tar_lacey_genus_2].update! rank: 470
      cdefs[:tar_lacey_species_2].update! rank: 480
      cdefs[:tar_lacey_country_2].update! rank: 490
      cdefs[:tar_lacey_quantity_2].update! rank: 500
      cdefs[:tar_lacey_uom_2].update! rank: 510
      cdefs[:tar_lacey_recycled_2].update! rank: 520
      cdefs[:tar_lacey_common_name_3].update! rank: 530
      cdefs[:tar_lacey_genus_3].update! rank: 540
      cdefs[:tar_lacey_species_3].update! rank: 550
      cdefs[:tar_lacey_country_3].update! rank: 560
      cdefs[:tar_lacey_quantity_3].update! rank: 570
      cdefs[:tar_lacey_uom_3].update! rank: 580
      cdefs[:tar_lacey_recycled_3].update! rank: 590
      cdefs[:tar_lacey_common_name_4].update! rank: 600
      cdefs[:tar_lacey_genus_4].update! rank: 610
      cdefs[:tar_lacey_species_4].update! rank: 620
      cdefs[:tar_lacey_country_4].update! rank: 630
      cdefs[:tar_lacey_quantity_4].update! rank: 640
      cdefs[:tar_lacey_uom_4].update! rank: 650
      cdefs[:tar_lacey_recycled_4].update! rank: 660
      cdefs[:tar_lacey_common_name_5].update! rank: 670
      cdefs[:tar_lacey_genus_5].update! rank: 680
      cdefs[:tar_lacey_species_5].update! rank: 690
      cdefs[:tar_lacey_country_5].update! rank: 700
      cdefs[:tar_lacey_quantity_5].update! rank: 710
      cdefs[:tar_lacey_uom_5].update! rank: 720
      cdefs[:tar_lacey_recycled_5].update! rank: 730
      cdefs[:tar_lacey_common_name_6].update! rank: 740
      cdefs[:tar_lacey_genus_6].update! rank: 750
      cdefs[:tar_lacey_species_6].update! rank: 760
      cdefs[:tar_lacey_country_6].update! rank: 770
      cdefs[:tar_lacey_quantity_6].update! rank: 780
      cdefs[:tar_lacey_uom_6].update! rank: 790
      cdefs[:tar_lacey_recycled_6].update! rank: 800
      cdefs[:tar_lacey_common_name_7].update! rank: 810
      cdefs[:tar_lacey_genus_7].update! rank: 820
      cdefs[:tar_lacey_species_7].update! rank: 830
      cdefs[:tar_lacey_country_7].update! rank: 840
      cdefs[:tar_lacey_quantity_7].update! rank: 850
      cdefs[:tar_lacey_uom_7].update! rank: 860
      cdefs[:tar_lacey_recycled_7].update! rank: 870
      cdefs[:tar_lacey_common_name_8].update! rank: 880
      cdefs[:tar_lacey_genus_8].update! rank: 890
      cdefs[:tar_lacey_species_8].update! rank: 900
      cdefs[:tar_lacey_country_8].update! rank: 910
      cdefs[:tar_lacey_quantity_8].update! rank: 920
      cdefs[:tar_lacey_uom_8].update! rank: 930
      cdefs[:tar_lacey_recycled_8].update! rank: 940
      cdefs[:tar_lacey_common_name_9].update! rank: 950
      cdefs[:tar_lacey_genus_9].update! rank: 960
      cdefs[:tar_lacey_species_9].update! rank: 970
      cdefs[:tar_lacey_country_9].update! rank: 980
      cdefs[:tar_lacey_quantity_9].update! rank: 990
      cdefs[:tar_lacey_uom_9].update! rank: 1000
      cdefs[:tar_lacey_recycled_9].update! rank: 1010
      cdefs[:tar_lacey_common_name_10].update! rank: 1020
      cdefs[:tar_lacey_genus_10].update! rank: 1030
      cdefs[:tar_lacey_species_10].update! rank: 1040
      cdefs[:tar_lacey_country_10].update! rank: 1050
      cdefs[:tar_lacey_quantity_10].update! rank: 1060
      cdefs[:tar_lacey_uom_10].update! rank: 1070
      cdefs[:tar_lacey_recycled_10].update! rank: 1080

      cdefs[:tar_fws_flag].update! rank: 1090
      cdefs[:tar_fws_general_name_1].update! rank: 1100
      cdefs[:tar_fws_genus_1].update! rank: 1110
      cdefs[:tar_fws_species_1].update! rank: 1120
      cdefs[:tar_fws_country_origin_1].update! rank: 1130
      cdefs[:tar_fws_cost_1].update! rank: 1140
      cdefs[:tar_fws_description_1].update! rank: 1150
      cdefs[:tar_fws_description_code_1].update! rank: 1160
      cdefs[:tar_fws_source_code_1].update! rank: 1170
      cdefs[:tar_fws_general_name_2].update! rank: 1180
      cdefs[:tar_fws_genus_2].update! rank: 1190
      cdefs[:tar_fws_species_2].update! rank: 1200
      cdefs[:tar_fws_country_origin_2].update! rank: 1210
      cdefs[:tar_fws_cost_2].update! rank: 1220
      cdefs[:tar_fws_description_2].update! rank: 1230
      cdefs[:tar_fws_description_code_2].update! rank: 1240
      cdefs[:tar_fws_source_code_2].update! rank: 1250
      cdefs[:tar_fws_general_name_3].update! rank: 1260
      cdefs[:tar_fws_genus_3].update! rank: 1270
      cdefs[:tar_fws_species_3].update! rank: 1280
      cdefs[:tar_fws_country_origin_3].update! rank: 1290
      cdefs[:tar_fws_cost_3].update! rank: 1300
      cdefs[:tar_fws_description_3].update! rank: 1310
      cdefs[:tar_fws_description_code_3].update! rank: 1320
      cdefs[:tar_fws_source_code_3].update! rank: 1330
      cdefs[:tar_fws_general_name_4].update! rank: 1340
      cdefs[:tar_fws_genus_4].update! rank: 1350
      cdefs[:tar_fws_species_4].update! rank: 1360
      cdefs[:tar_fws_country_origin_4].update! rank: 1370
      cdefs[:tar_fws_cost_4].update! rank: 1380
      cdefs[:tar_fws_description_4].update! rank: 1390
      cdefs[:tar_fws_description_code_4].update! rank: 1400
      cdefs[:tar_fws_source_code_4].update! rank: 1410
      cdefs[:tar_fws_general_name_5].update! rank: 1420
      cdefs[:tar_fws_genus_5].update! rank: 1430
      cdefs[:tar_fws_species_5].update! rank: 1440
      cdefs[:tar_fws_country_origin_5].update! rank: 1450
      cdefs[:tar_fws_cost_5].update! rank: 1460
      cdefs[:tar_fws_description_5].update! rank: 1470
      cdefs[:tar_fws_description_code_5].update! rank: 1480
      cdefs[:tar_fws_source_code_5].update! rank: 1490

      cdefs[:var_quantity].update! rank: 1500
      cdefs[:var_hts_line].update! rank: 1510
      cdefs[:var_lacey_species].update! rank: 1520
      cdefs[:var_lacey_country_harvest].update! rank: 1530

    end
  end

  def down
    return unless MasterSetup.get.custom_feature?("Target")

    enable_product_type
  end

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions([:prod_part_number, :prod_vendor_order_point, :prod_type,
      :prod_vendor_style, :prod_long_description, :prod_aphis, :prod_usda, :prod_epa, :prod_cps, :prod_tsca,
      :prod_required_documents, :tar_country_of_origin, :tar_spi_primary, :tar_xvv, :tar_component_description,
      :tar_cvd_case, :tar_add_case, :tar_dot_program, :tar_dot_box_number, :tar_fda_product_code, :tar_fda_cargo_status, :tar_fda_food,
      :tar_fda_affirmation_code_1, :tar_fda_affirmation_code_2, :tar_fda_affirmation_code_3,
      :tar_fda_affirmation_code_4, :tar_fda_affirmation_code_5, :tar_fda_affirmation_code_6, :tar_fda_affirmation_code_7,
      :tar_fda_affirmation_qualifier_1, :tar_fda_affirmation_qualifier_2, :tar_fda_affirmation_qualifier_3, :tar_fda_affirmation_qualifier_4,
      :tar_fda_affirmation_qualifier_5, :tar_fda_affirmation_qualifier_6, :tar_fda_affirmation_qualifier_7, :tar_lacey_common_name_1,
      :tar_lacey_common_name_2, :tar_lacey_common_name_3, :tar_lacey_common_name_4, :tar_lacey_common_name_5, :tar_lacey_common_name_6,
      :tar_lacey_common_name_7, :tar_lacey_common_name_8, :tar_lacey_common_name_9, :tar_lacey_common_name_10, :tar_lacey_genus_1,
      :tar_lacey_genus_2, :tar_lacey_genus_3, :tar_lacey_genus_4, :tar_lacey_genus_5, :tar_lacey_genus_6, :tar_lacey_genus_7,
      :tar_lacey_genus_8, :tar_lacey_genus_9, :tar_lacey_genus_10, :tar_lacey_species_1, :tar_lacey_species_2, :tar_lacey_species_3,
      :tar_lacey_species_4, :tar_lacey_species_5, :tar_lacey_species_6, :tar_lacey_species_7, :tar_lacey_species_8, :tar_lacey_species_9,
      :tar_lacey_species_10, :tar_lacey_country_1, :tar_lacey_country_2, :tar_lacey_country_3, :tar_lacey_country_4, :tar_lacey_country_5,
      :tar_lacey_country_6, :tar_lacey_country_7, :tar_lacey_country_8, :tar_lacey_country_9, :tar_lacey_country_10, :tar_lacey_quantity_1,
      :tar_lacey_quantity_2, :tar_lacey_quantity_3, :tar_lacey_quantity_4, :tar_lacey_quantity_5, :tar_lacey_quantity_6, :tar_lacey_quantity_7,
      :tar_lacey_quantity_8, :tar_lacey_quantity_9, :tar_lacey_quantity_10, :tar_lacey_uom_1, :tar_lacey_uom_2, :tar_lacey_uom_3, :tar_lacey_uom_4,
      :tar_lacey_uom_5, :tar_lacey_uom_6, :tar_lacey_uom_7, :tar_lacey_uom_8, :tar_lacey_uom_9, :tar_lacey_uom_10, :tar_lacey_recycled_1, :tar_lacey_recycled_2,
      :tar_lacey_recycled_3, :tar_lacey_recycled_4, :tar_lacey_recycled_5, :tar_lacey_recycled_6, :tar_lacey_recycled_7, :tar_lacey_recycled_8,
      :tar_lacey_recycled_9, :tar_lacey_recycled_10, :tar_fws_genus_1, :tar_fws_genus_2, :tar_fws_genus_3, :tar_fws_genus_4, :tar_fws_genus_5, :tar_fws_species_1,
      :tar_fws_species_2, :tar_fws_species_3, :tar_fws_species_4, :tar_fws_species_5, :tar_fws_general_name_1, :tar_fws_general_name_2,
      :tar_fws_general_name_3, :tar_fws_general_name_4, :tar_fws_general_name_5, :tar_fws_country_origin_1, :tar_fws_country_origin_2,
      :tar_fws_country_origin_3, :tar_fws_country_origin_4, :tar_fws_country_origin_5, :tar_fws_cost_1, :tar_fws_cost_2, :tar_fws_cost_3,
      :tar_fws_cost_4, :tar_fws_cost_5, :tar_fws_description_1, :tar_fws_description_2, :tar_fws_description_3, :tar_fws_description_4, :tar_fws_description_5,
      :tar_fws_description_code_1, :tar_fws_description_code_2, :tar_fws_description_code_3, :tar_fws_description_code_4, :tar_fws_description_code_5,
      :tar_fws_source_code_1, :tar_fws_source_code_2, :tar_fws_source_code_3, :tar_fws_source_code_4, :tar_fws_source_code_5,
      :var_quantity, :var_hts_line, :var_lacey_species, :var_lacey_country_harvest, :tar_dot_flag, :tar_fda_flag, :tar_fws_flag, :tar_lacey_flag
    ])
  end
end
