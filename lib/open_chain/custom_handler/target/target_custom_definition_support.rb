require 'open_chain/custom_handler/custom_definition_support'

module OpenChain; module CustomHandler; module Target; module TargetCustomDefinitionSupport
  extend ActiveSupport::Concern

  CUSTOM_DEFINITION_INSTRUCTIONS = {
    prod_part_number: { label: 'Target Part Number', data_type: :string, module_type: 'Product', cdef_uid: "prod_part_number" },
    prod_vendor_order_point: { label: 'Vendor Order Point', data_type: :string, module_type: 'Product', cdef_uid: "prod_vendor_order_point" },
    prod_type: { label: "Product Type", data_type: :string, module_type: "Product", cdef_uid: "prod_type" },
    prod_vendor_style: { label: "Vendor Style", data_type: :string, module_type: "Product", cdef_uid: "prod_vendor_style" },
    prod_long_description: { label: "Long Description", data_type: :text, module_type: "Product", cdef_uid: "prod_long_description" },
    prod_aphis: { label: "APHIS?", data_type: :boolean, module_type: "Product", cdef_uid: "prod_aphis" },
    prod_usda: { label: "USDA?", data_type: :boolean, module_type: "Product", cdef_uid: "prod_usda" },
    prod_epa: { label: "EPA?", data_type: :boolean, module_type: "Product", cdef_uid: "prod_epa" },
    prod_cps: { label: "CPS?", data_type: :boolean, module_type: "Product", cdef_uid: "prod_cps" },
    prod_tsca: { label: "TSCA?", data_type: :boolean, module_type: "Product", cdef_uid: "prod_tsca" },
    prod_required_documents: { label: "Required Documents", data_type: :text, module_type: "Product", cdef_uid: "prod_required_documents" },
    tar_external_line_number: { label: "External Line Number", data_type: :integer, module_type: "TariffRecord", cdef_uid: "tar_external_line_number" },
    tar_country_of_origin: { label: "Country Of Origin", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_country_of_origin" },
    tar_spi_primary: { label: "Primary SPI", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_spi_primary" },
    tar_xvv: { label: "XVV Indicator", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_xvv" },
    tar_component_description: { label: "Component Description", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_component_description" },
    tar_cvd_case: { label: "CVD Case Number", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_cvd_case" },
    tar_add_case: { label: "ADD Case Number", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_add_case" },
    tar_dot_flag: { label: "DOT?", data_type: :boolean, module_type: "TariffRecord", cdef_uid: "tar_dot_flag" },
    tar_dot_program: { label: "DOT Program Code", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_dot_program" },
    tar_dot_box_number: { label: "DOT Box Number", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_dot_box_number" },
    tar_fda_flag: { label: "FDA?", data_type: :boolean, module_type: "TariffRecord", cdef_uid: "tar_fda_flag" },
    tar_fda_product_code: { label: "FDA Product Code", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fda_product_code" },
    tar_fda_cargo_status: { label: "FDA Cargo Status", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fda_cargo_status" },
    tar_fda_food: { label: "FDA Food?", data_type: :boolean, module_type: "TariffRecord", cdef_uid: "tar_fda_food" },
    tar_fda_affirmation_code_1: { label: "FDA Aff. Comp. Code 1", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fda_affirmation_code_1" },
    tar_fda_affirmation_code_2: { label: "FDA Aff. Comp. Code 2", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fda_affirmation_code_2" },
    tar_fda_affirmation_code_3: { label: "FDA Aff. Comp. Code 3", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fda_affirmation_code_3" },
    tar_fda_affirmation_code_4: { label: "FDA Aff. Comp. Code 4", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fda_affirmation_code_4" },
    tar_fda_affirmation_code_5: { label: "FDA Aff. Comp. Code 5", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fda_affirmation_code_5" },
    tar_fda_affirmation_code_6: { label: "FDA Aff. Comp. Code 6", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fda_affirmation_code_6" },
    tar_fda_affirmation_code_7: { label: "FDA Aff. Comp. Code 7", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fda_affirmation_code_7" },
    tar_fda_affirmation_qualifier_1: { label: "FDA Aff. Comp. Qual. 1", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fda_affirmation_qualifier_1" },
    tar_fda_affirmation_qualifier_2: { label: "FDA Aff. Comp. Qual. 2", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fda_affirmation_qualifier_2" },
    tar_fda_affirmation_qualifier_3: { label: "FDA Aff. Comp. Qual. 3", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fda_affirmation_qualifier_3" },
    tar_fda_affirmation_qualifier_4: { label: "FDA Aff. Comp. Qual. 4", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fda_affirmation_qualifier_4" },
    tar_fda_affirmation_qualifier_5: { label: "FDA Aff. Comp. Qual. 5", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fda_affirmation_qualifier_5" },
    tar_fda_affirmation_qualifier_6: { label: "FDA Aff. Comp. Qual. 6", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fda_affirmation_qualifier_6" },
    tar_fda_affirmation_qualifier_7: { label: "FDA Aff. Comp. Qual. 7", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fda_affirmation_qualifier_7" },
    tar_lacey_flag: { label: "Lacey?", data_type: :boolean, module_type: "TariffRecord", cdef_uid: "tar_lacey_flag" },
    tar_lacey_common_name_1: { label: "Lacey Common Name 1", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_common_name_1" },
    tar_lacey_common_name_2: { label: "Lacey Common Name 2", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_common_name_2" },
    tar_lacey_common_name_3: { label: "Lacey Common Name 3", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_common_name_3" },
    tar_lacey_common_name_4: { label: "Lacey Common Name 4", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_common_name_4" },
    tar_lacey_common_name_5: { label: "Lacey Common Name 5", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_common_name_5" },
    tar_lacey_common_name_6: { label: "Lacey Common Name 6", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_common_name_6" },
    tar_lacey_common_name_7: { label: "Lacey Common Name 7", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_common_name_7" },
    tar_lacey_common_name_8: { label: "Lacey Common Name 8", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_common_name_8" },
    tar_lacey_common_name_9: { label: "Lacey Common Name 9", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_common_name_9" },
    tar_lacey_common_name_10: { label: "Lacey Common Name 10", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_common_name_10" },
    tar_lacey_genus_1: { label: "Lacey Genus 1", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_genus_1" },
    tar_lacey_genus_2: { label: "Lacey Genus 2", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_genus_2" },
    tar_lacey_genus_3: { label: "Lacey Genus 3", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_genus_3" },
    tar_lacey_genus_4: { label: "Lacey Genus 4", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_genus_4" },
    tar_lacey_genus_5: { label: "Lacey Genus 5", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_genus_5" },
    tar_lacey_genus_6: { label: "Lacey Genus 6", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_genus_6" },
    tar_lacey_genus_7: { label: "Lacey Genus 7", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_genus_7" },
    tar_lacey_genus_8: { label: "Lacey Genus 8", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_genus_8" },
    tar_lacey_genus_9: { label: "Lacey Genus 9", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_genus_9" },
    tar_lacey_genus_10: { label: "Lacey Genus 10", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_genus_10" },
    tar_lacey_species_1: { label: "Lacey Species 1", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_species_1" },
    tar_lacey_species_2: { label: "Lacey Species 2", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_species_2" },
    tar_lacey_species_3: { label: "Lacey Species 3", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_species_3" },
    tar_lacey_species_4: { label: "Lacey Species 4", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_species_4" },
    tar_lacey_species_5: { label: "Lacey Species 5", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_species_5" },
    tar_lacey_species_6: { label: "Lacey Species 6", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_species_6" },
    tar_lacey_species_7: { label: "Lacey Species 7", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_species_7" },
    tar_lacey_species_8: { label: "Lacey Species 8", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_species_8" },
    tar_lacey_species_9: { label: "Lacey Species 9", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_species_9" },
    tar_lacey_species_10: { label: "Lacey Species 10", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_species_10" },
    tar_lacey_country_1: { label: "Lacey Country of Harvest 1", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_country_1" },
    tar_lacey_country_2: { label: "Lacey Country of Harvest 2", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_country_2" },
    tar_lacey_country_3: { label: "Lacey Country of Harvest 3", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_country_3" },
    tar_lacey_country_4: { label: "Lacey Country of Harvest 4", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_country_4" },
    tar_lacey_country_5: { label: "Lacey Country of Harvest 5", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_country_5" },
    tar_lacey_country_6: { label: "Lacey Country of Harvest 6", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_country_6" },
    tar_lacey_country_7: { label: "Lacey Country of Harvest 7", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_country_7" },
    tar_lacey_country_8: { label: "Lacey Country of Harvest 8", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_country_8" },
    tar_lacey_country_9: { label: "Lacey Country of Harvest 9", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_country_9" },
    tar_lacey_country_10: { label: "Lacey Country of Harvest 10", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_country_10" },
    tar_lacey_quantity_1: { label: "Lacey Quantity 1", data_type: :decimal, module_type: "TariffRecord", cdef_uid: "tar_lacey_quantity_1" },
    tar_lacey_quantity_2: { label: "Lacey Quantity 2", data_type: :decimal, module_type: "TariffRecord", cdef_uid: "tar_lacey_quantity_2" },
    tar_lacey_quantity_3: { label: "Lacey Quantity 3", data_type: :decimal, module_type: "TariffRecord", cdef_uid: "tar_lacey_quantity_3" },
    tar_lacey_quantity_4: { label: "Lacey Quantity 4", data_type: :decimal, module_type: "TariffRecord", cdef_uid: "tar_lacey_quantity_4" },
    tar_lacey_quantity_5: { label: "Lacey Quantity 5", data_type: :decimal, module_type: "TariffRecord", cdef_uid: "tar_lacey_quantity_5" },
    tar_lacey_quantity_6: { label: "Lacey Quantity 6", data_type: :decimal, module_type: "TariffRecord", cdef_uid: "tar_lacey_quantity_6" },
    tar_lacey_quantity_7: { label: "Lacey Quantity 7", data_type: :decimal, module_type: "TariffRecord", cdef_uid: "tar_lacey_quantity_7" },
    tar_lacey_quantity_8: { label: "Lacey Quantity 8", data_type: :decimal, module_type: "TariffRecord", cdef_uid: "tar_lacey_quantity_8" },
    tar_lacey_quantity_9: { label: "Lacey Quantity 9", data_type: :decimal, module_type: "TariffRecord", cdef_uid: "tar_lacey_quantity_9" },
    tar_lacey_quantity_10: { label: "Lacey Quantity 10", data_type: :decimal, module_type: "TariffRecord", cdef_uid: "tar_lacey_quantity_10" },
    tar_lacey_uom_1: { label: "Lacey UOM 1", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_uom_1" },
    tar_lacey_uom_2: { label: "Lacey UOM 2", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_uom_2" },
    tar_lacey_uom_3: { label: "Lacey UOM 3", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_uom_3" },
    tar_lacey_uom_4: { label: "Lacey UOM 4", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_uom_4" },
    tar_lacey_uom_5: { label: "Lacey UOM 5", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_uom_5" },
    tar_lacey_uom_6: { label: "Lacey UOM 6", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_uom_6" },
    tar_lacey_uom_7: { label: "Lacey UOM 7", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_uom_7" },
    tar_lacey_uom_8: { label: "Lacey UOM 8", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_uom_8" },
    tar_lacey_uom_9: { label: "Lacey UOM 9", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_uom_9" },
    tar_lacey_uom_10: { label: "Lacey UOM 10", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_lacey_uom_10" },
    tar_lacey_recycled_1: { label: "Lacey Percent Recycled 1", data_type: :decimal, module_type: "TariffRecord", cdef_uid: "tar_lacey_recycled_1" },
    tar_lacey_recycled_2: { label: "Lacey Percent Recycled 2", data_type: :decimal, module_type: "TariffRecord", cdef_uid: "tar_lacey_recycled_2" },
    tar_lacey_recycled_3: { label: "Lacey Percent Recycled 3", data_type: :decimal, module_type: "TariffRecord", cdef_uid: "tar_lacey_recycled_3" },
    tar_lacey_recycled_4: { label: "Lacey Percent Recycled 4", data_type: :decimal, module_type: "TariffRecord", cdef_uid: "tar_lacey_recycled_4" },
    tar_lacey_recycled_5: { label: "Lacey Percent Recycled 5", data_type: :decimal, module_type: "TariffRecord", cdef_uid: "tar_lacey_recycled_5" },
    tar_lacey_recycled_6: { label: "Lacey Percent Recycled 6", data_type: :decimal, module_type: "TariffRecord", cdef_uid: "tar_lacey_recycled_6" },
    tar_lacey_recycled_7: { label: "Lacey Percent Recycled 7", data_type: :decimal, module_type: "TariffRecord", cdef_uid: "tar_lacey_recycled_7" },
    tar_lacey_recycled_8: { label: "Lacey Percent Recycled 8", data_type: :decimal, module_type: "TariffRecord", cdef_uid: "tar_lacey_recycled_8" },
    tar_lacey_recycled_9: { label: "Lacey Percent Recycled 9", data_type: :decimal, module_type: "TariffRecord", cdef_uid: "tar_lacey_recycled_9" },
    tar_lacey_recycled_10: { label: "Lacey Percent Recycled 10", data_type: :decimal, module_type: "TariffRecord", cdef_uid: "tar_lacey_recycled_10" },
    tar_fws_flag: { label: "FWS?", data_type: :boolean, module_type: "TariffRecord", cdef_uid: "tar_fws_flag" },
    tar_fws_genus_1: { label: "FWS Genus 1", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fws_genus_1" },
    tar_fws_genus_2: { label: "FWS Genus 2", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fws_genus_2" },
    tar_fws_genus_3: { label: "FWS Genus 3", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fws_genus_3" },
    tar_fws_genus_4: { label: "FWS Genus 4", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fws_genus_4" },
    tar_fws_genus_5: { label: "FWS Genus 5", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fws_genus_5" },
    tar_fws_species_1: { label: "FWS Species 1", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fws_species_1" },
    tar_fws_species_2: { label: "FWS Species 2", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fws_species_2" },
    tar_fws_species_3: { label: "FWS Species 3", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fws_species_3" },
    tar_fws_species_4: { label: "FWS Species 4", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fws_species_4" },
    tar_fws_species_5: { label: "FWS Species 5", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fws_species_5" },
    tar_fws_general_name_1: { label: "FWS General Name 1", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fws_general_name_1" },
    tar_fws_general_name_2: { label: "FWS General Name 2", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fws_general_name_2" },
    tar_fws_general_name_3: { label: "FWS General Name 3", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fws_general_name_3" },
    tar_fws_general_name_4: { label: "FWS General Name 4", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fws_general_name_4" },
    tar_fws_general_name_5: { label: "FWS General Name 5", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fws_general_name_5" },
    tar_fws_country_origin_1: { label: "FWS Country of Origin 1", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fws_country_origin_1" },
    tar_fws_country_origin_2: { label: "FWS Country of Origin 2", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fws_country_origin_2" },
    tar_fws_country_origin_3: { label: "FWS Country of Origin 3", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fws_country_origin_3" },
    tar_fws_country_origin_4: { label: "FWS Country of Origin 4", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fws_country_origin_4" },
    tar_fws_country_origin_5: { label: "FWS Country of Origin 5", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fws_country_origin_5" },
    tar_fws_cost_1: { label: "FWS Cost 1", data_type: :decimal, module_type: "TariffRecord", cdef_uid: "tar_fws_cost_1" },
    tar_fws_cost_2: { label: "FWS Cost 2", data_type: :decimal, module_type: "TariffRecord", cdef_uid: "tar_fws_cost_2" },
    tar_fws_cost_3: { label: "FWS Cost 3", data_type: :decimal, module_type: "TariffRecord", cdef_uid: "tar_fws_cost_3" },
    tar_fws_cost_4: { label: "FWS Cost 4", data_type: :decimal, module_type: "TariffRecord", cdef_uid: "tar_fws_cost_4" },
    tar_fws_cost_5: { label: "FWS Cost 5", data_type: :decimal, module_type: "TariffRecord", cdef_uid: "tar_fws_cost_5" },
    tar_fws_description_1: { label: "FWS Description 1", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fws_description_1" },
    tar_fws_description_2: { label: "FWS Description 2", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fws_description_2" },
    tar_fws_description_3: { label: "FWS Description 3", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fws_description_3" },
    tar_fws_description_4: { label: "FWS Description 4", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fws_description_4" },
    tar_fws_description_5: { label: "FWS Description 5", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fws_description_5" },
    tar_fws_description_code_1: { label: "FWS Description Code 1", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fws_description_code_1" },
    tar_fws_description_code_2: { label: "FWS Description Code 2", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fws_description_code_2" },
    tar_fws_description_code_3: { label: "FWS Description Code 3", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fws_description_code_3" },
    tar_fws_description_code_4: { label: "FWS Description Code 4", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fws_description_code_4" },
    tar_fws_description_code_5: { label: "FWS Description Code 5", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fws_description_code_5" },
    tar_fws_source_code_1: { label: "FWS Source Code 1", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fws_source_code_1" },
    tar_fws_source_code_2: { label: "FWS Source Code 2", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fws_source_code_2" },
    tar_fws_source_code_3: { label: "FWS Source Code 3", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fws_source_code_3" },
    tar_fws_source_code_4: { label: "FWS Source Code 4", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fws_source_code_4" },
    tar_fws_source_code_5: { label: "FWS Source Code 5", data_type: :string, module_type: "TariffRecord", cdef_uid: "tar_fws_source_code_5" },
    var_quantity: { label: "Quantity", data_type: :decimal, module_type: "Variant", cdef_uid: "var_quantity" },
    var_hts_line: { label: "HTS Line Number", data_type: :integer, module_type: "Variant", cdef_uid: "var_hts_line" },
    var_lacey_species: { label: "Lacey Species", data_type: :string, module_type: "Variant", cdef_uid: "var_lacey_species" },
    var_lacey_country_harvest: { label: "Lacey Country of Harvest", data_type: :string, module_type: "Variant", cdef_uid: "var_lacey_country_harvest" }
  }.freeze

  included do
    extend OpenChain::CustomHandler::CustomDefinitionSupport
  end

  module ClassMethods
    def prep_custom_definitions fields
      prep_custom_defs fields, CUSTOM_DEFINITION_INSTRUCTIONS
    end
  end

end; end; end; end