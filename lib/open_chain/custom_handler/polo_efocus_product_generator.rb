require 'open_chain/custom_handler/product_generator'
require 'open_chain/custom_handler/polo/polo_custom_definition_support'

module OpenChain; module CustomHandler; class PoloEfocusProductGenerator < ProductGenerator
  include OpenChain::CustomHandler::Polo::PoloCustomDefinitionSupport

  SYNC_CODE ||= 'efocus-product'

  def self.run_schedulable opts = {}
    self.new(opts).generate
  end

  def initialize opts = {}
    super(opts)
  end

  #Superclass requires this method
  def sync_code
    SYNC_CODE
  end

  def preprocess_header_row row, opts = {}
    # Since index 7 is clean_fiber_content, and that ends up under fiber_content, we do not want clean_fiber_content
    # as a header. I am removing it from the header, then moving all the other elements back into their normal positions.
    row.delete(7)
    trailing_hash = row.slice!(0, 1, 2, 3, 4, 5, 6)
    trailing_hash.each do |k, v|
      row[k - 1] = v
    end
    [row]
  end

  def preprocess_row row, opts = {}
    # Index 7 is clean_fiber_content. We want to make sure that, if that is present, that gets placed under fiber_content.
    # I am replacing fiber_content with clean_fiber_content (If present) then removing the clean_fiber_content row and moving
    # all elements back to where they were.
    if row[7].present?
      row[6] = row[7]
      row.delete(7)
    else
      row.delete(7)
    end
    trailing_hash = row.slice!(0, 1, 2, 3, 4, 5, 6)
    trailing_hash.each do |k, v|
      row[k - 1] = v
    end
    [row]
  end

  def generate
    count = nil
    begin
      file = sync_xls
      ftp_file file if (count = self.row_count) > 0
    end while count > 0
  end

  def auto_confirm?
    false
  end

  def ftp_credentials
    {:server=>'ftp2.vandegriftinc.com',:username=>'VFITRACK',:password=>'RL2VFftp',:folder=>"to_ecs/Ralph_Lauren/efocus_products"}
  end

  def query
    @cdefs ||= self.class.prep_custom_definitions self.class.cdefs

    fields = [
        "products.id",
        cd_s(@cdefs[:bartho_customer_id]),
        cd_s(@cdefs[:season]),
        "\"US\" as `#{ModelField.find_by_uid(:class_cntry_iso).label}`",
        cd_s(@cdefs[:product_area]),
        cd_s(@cdefs[:msl_board_number]),
        "IFNULL(products.unique_identifier,\"\") AS `#{ModelField.find_by_uid(:prod_uid).label}`",
        cd_s(@cdefs[:fiber_content]),
        cd_s(@cdefs[:clean_fiber_content]),
        "IFNULL(products.name,\"\") AS `#{ModelField.find_by_uid(:prod_name).label}`",
        "\"\" AS `Blank 1`",
        cd_s(@cdefs[:knit_woven]),
        "IFNULL(tariff_records.hts_1,\"\") AS `#{ModelField.find_by_uid(:hts_hts_1).label}`",
        "IFNULL((SELECT category FROM official_quotas WHERE official_quotas.hts_code = tariff_records.hts_1 AND official_quotas.country_id = classifications.country_id),\"\") as `#{ModelField.find_by_uid(:hts_hts_1_qc).label}`",
        "IFNULL((SELECT general_rate FROM official_tariffs WHERE official_tariffs.hts_code = tariff_records.hts_1 AND official_tariffs.country_id = classifications.country_id),\"\") as `#{ModelField.find_by_uid(:hts_hts_1_gr).label}`",
        "IFNULL(tariff_records.hts_2,\"\") AS `#{ModelField.find_by_uid(:hts_hts_2).label}`",
        "IFNULL((SELECT category FROM official_quotas WHERE official_quotas.hts_code = tariff_records.hts_2 AND official_quotas.country_id = classifications.country_id),\"\") as `#{ModelField.find_by_uid(:hts_hts_2_qc).label}`",
        "IFNULL((SELECT general_rate FROM official_tariffs WHERE official_tariffs.hts_code = tariff_records.hts_2 AND official_tariffs.country_id = classifications.country_id),\"\") as `#{ModelField.find_by_uid(:hts_hts_2_gr).label}`"]
    self.class.cdefs_range_1.each do |cd|
      fields << cd_s(@cdefs[cd])
    end

    fields << "\"\" AS `Blank 2`"
    fields << cd_s(@cdefs[:semi_precious])
    fields << cd_s(@cdefs[:semi_precious_type])
    fields << cd_s(@cdefs[:telescopic_shaft])
    fields << cd_s(@cdefs[:unit_price])
    fields << "\"\"AS `Vendor Code`"
    self.class.cdefs_range_2.each do |cd|
      if cd == :fish_wildlife
        fields << cd_s(@cdefs[cd], boolean_y_n: true)
      else
        fields << cd_s(@cdefs[cd])
      end
    end

    r = "SELECT #{fields.join(", ")}
FROM products
INNER JOIN classifications  on classifications.product_id = products.id
INNER JOIN countries countries on countries.iso_code = 'US' and classifications.country_id = countries.id
LEFT OUTER JOIN tariff_records tariff_records on tariff_records.classification_id = classifications.id
INNER JOIN custom_values cust_id ON products.id = cust_id.customizable_id AND cust_id.customizable_type = 'Product' and cust_id.custom_definition_id = #{@cdefs[:bartho_customer_id].id} and length(ifnull(rtrim(cust_id.string_value), '')) > 0
LEFT OUTER JOIN custom_values test_style ON products.id = test_style.customizable_id AND test_style.customizable_type = 'Product' and test_style.custom_definition_id = #{@cdefs[:test_style].id}
LEFT OUTER JOIN custom_values set_type ON classifications.id = set_type.customizable_id AND set_type.customizable_type = 'Classification' and set_type.custom_definition_id = #{@cdefs[:set_type].id}
INNER JOIN (#{inner_query}) inner_query ON inner_query.id = products.id
ORDER BY products.id, tariff_records.line_number
"
  end

  def inner_query
    # This query is here soley to allow us to do limits...it needs to be done as subquery like this because there can potentially be more than one row per product.
    # If we didn't do this, then there's the possibility that we chop off a tariff record from a query if we just added a limit to a single query.
    r = "SELECT distinct inner_products.id
FROM products inner_products
INNER JOIN classifications inner_classifications on inner_classifications.product_id = inner_products.id
INNER JOIN countries inner_countries on inner_countries.iso_code = 'US' and inner_classifications.country_id = inner_countries.id
LEFT OUTER JOIN tariff_records inner_tariff_records on inner_tariff_records.classification_id = inner_classifications.id
"

# The JOINS + WHERE clause below generates files that need to be synced
# && Have an HTS 1, 2, or 3 value OR are 'RL' Sets
# && have Barthco Customer IDs
# && DO NOT have a 'Test Style' value,
    if self.custom_where.blank?
      r += "#{Product.need_sync_join_clause(sync_code, 'inner_products')}
INNER JOIN custom_values inner_cust_id ON inner_products.id = inner_cust_id.customizable_id AND inner_cust_id.customizable_type = 'Product' and inner_cust_id.custom_definition_id = #{@cdefs[:bartho_customer_id].id} and length(ifnull(rtrim(inner_cust_id.string_value), '')) > 0
LEFT OUTER JOIN custom_values inner_test_style ON inner_products.id = inner_test_style.customizable_id AND inner_test_style.customizable_type = 'Product' and inner_test_style.custom_definition_id = #{@cdefs[:test_style].id}
LEFT OUTER JOIN custom_values inner_set_type ON inner_classifications.id = inner_set_type.customizable_id AND inner_set_type.customizable_type = 'Classification' and inner_set_type.custom_definition_id = #{@cdefs[:set_type].id}
WHERE #{Product.need_sync_where_clause('inner_products', Time.zone.now - 3.hours)}
AND (length(inner_tariff_records.hts_1) > 0 OR length(inner_tariff_records.hts_2) > 0 OR length(inner_tariff_records.hts_3) > 0 OR (inner_set_type.string_value = 'RL'))
AND (inner_test_style.string_value IS NULL OR length(rtrim(inner_test_style.string_value)) = 0)
"
    else
      r += self.custom_where
    end

    r += " ORDER BY inner_products.id ASC"
    r + " LIMIT #{max_results}"
  end

  def max_results
    5000
  end

  def self.cdefs
    [:bartho_customer_id, :test_style, :season, :product_area, :msl_board_number, :fiber_content, :clean_fiber_content, :knit_woven, :semi_precious, :semi_precious_type, :telescopic_shaft, :unit_price] + cdefs_range_1 + cdefs_range_2
  end

  def self.cdefs_range_1
    [:stitch_count_vertical, :stitch_count_horizontal, :grams_square_meter, :knit_type, :type_of_bottom, :functional_neck_closure, :significantly_napped, :back_type, :defined_armholes,
     :strap_width, :pass_water_resistant_test, :type_of_coating, :padding_or_filling, :meets_down_requirments, :tightening_at_waist, :denim, :denim_color, :corduroy, :shearling, :total_back_panels,
     :short_fall_above_knee, :mesh_lining, :full_elastic_waistband, :full_functional_drawstring, :cover_crown_of_head, :wholly_or_partially_braid, :yarn_dyed, :colors_in_warp_weft, :piece_dyed, :printed, :solid,
     :ounces_sq_yd, :size_scale, :type_of_fabric, :weight_of_fabric, :form_fitting_or_loose_fitting, :functional_open_fly, :fly_covered, :tightening_at_cuffs, :embellishments_or_ornamentation, :sizing,
     :sold_in_sleepwear_dept, :pcs_in_set, :sold_as_set, :footwear_upper, :footwear_outsole, :welted, :cover_the_ankle, :length_cm, :width_cm, :height_cm, :secure_closure, :closure_type,
     :multiple_compartment, :fourchettes_for_gloves, :lined_for_gloves, :seamed, :components, :cost_of_component, :weight_of_components, :material_content_of_posts_earrings, :filled, :type_of_fill, :coated]
  end

  def self.cdefs_range_2
    [:country_of_origin, :fish_wildlife, :common_name_1, :scientific_name_1, :fish_wildlife_origin_1, :fish_wildlife_source_1, :royalty_percentage, :chart_comments, :binding_ruling_number, :binding_ruling_type,
     :mid, :fda_product_code, :effective_date, :price_uom, :special_program_indicator, :cvd_case, :add_case, :ptp_code, :terms_of_sale, :set_type]
  end

end; end; end
