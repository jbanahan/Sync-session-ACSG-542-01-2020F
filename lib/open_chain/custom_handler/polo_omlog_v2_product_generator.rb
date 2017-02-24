require 'open_chain/custom_handler/product_generator'
require 'open_chain/custom_handler/polo/polo_custom_definition_support'

module OpenChain; module CustomHandler; class PoloOmlogV2ProductGenerator < ProductGenerator
  include OpenChain::CustomHandler::Polo::PoloCustomDefinitionSupport

  def self.run_schedulable opts={}
    h = self.new opts.with_indifferent_access
    h.generate
  end

  def preprocess_header_row row, opts = {}
    row.delete(8)
    trailing_hash = row.slice!(0, 1, 2, 3, 4, 5, 6, 7)
    trailing_hash.each do |k, v|
      row[k - 1] = v
    end
    [row]
  end

  def preprocess_row row, opts = {}
    if row[8].present?
      row[7] = row[8]
      row.delete(8)
    else
      row.delete(8)
    end
    trailing_hash = row.slice!(0, 1, 2, 3, 4, 5, 6, 7)
    trailing_hash.each do |k, v|
      row[k - 1] = v
    end
    [row]
  end

  def generate
    f = nil
    begin
      f = sync_csv
      ftp_file(f) unless f.nil?
    end while !f.nil?
  end

  def initialize opts={}
    super
    @cdefs = self.class.prep_custom_definitions self.class.cdefs
    @max_results = opts[:max_results]
  end

  def sync_code
    "omlog-product-v2"
  end

  def ftp_credentials
    {:server=>'ftp.omlogasia.com',:username=>'ftp06user21',:password=>'kXynC3jm',:folder=>'chain'}
  end

  #overriding to handle special splitting of CSM numbers
  def sync_csv include_headers=true
    f = Tempfile.new(['ProductSync','.csv'])
    cursor = 0
    sync do |rv|
      if include_headers || cursor > 0
        csm_numbers = rv[1].blank? ? [''] : rv[1].split("\n")
        csm_numbers.each do |c|
          max_col = rv.keys.sort.last
          row = []
          (0..max_col).each do |i|
            v = i==1 ? c : rv[i]
            v = "" if v.blank?
            v = v.hts_format if [10,13,16].include?(i)
            row << v.to_s.gsub(/\r?\n/, " ")
          end
          f << row.to_csv
        end
      end
      cursor += 1
    end
    f.flush
    if (include_headers && cursor > 1) || cursor > 0
      return f
    else
      f.unlink
      return nil
    end
  end

  def query
    q = "SELECT products.id,
#{cd_s @cdefs[:lin_number]},
#{cd_s @cdefs[:csm_numbers]},
#{cd_s @cdefs[:season]},
'IT' as 'Classification - Country ISO Code',
#{cd_s @cdefs[:product_area]},
#{cd_s @cdefs[:msl_board_number]},
products.unique_identifier as 'Style',
#{cd_s @cdefs[:fiber_content]},
#{cd_s @cdefs[:clean_fiber_content]},
products.name as 'Name',
#{cd_s @cdefs[:knit_woven], query_alias: "Knit / Woven?"},
tariff_records.hts_1 as 'Tariff - HTS Code 1',
(select category from official_quotas where official_quotas.hts_code = tariff_records.hts_1 and official_quotas.country_id = classifications.country_id LIMIT 1) as 'Tariff - 1 - Quota Category',
(select general_rate from official_tariffs where official_tariffs.hts_code = tariff_records.hts_1 and official_tariffs.country_id = classifications.country_id) as 'Tariff - 1 - General Rate',
tariff_records.hts_2 as 'Tariff - HTS Code 2',
(select category from official_quotas where official_quotas.hts_code = tariff_records.hts_2 and official_quotas.country_id = classifications.country_id LIMIT 1) as 'Tariff - 2 - Quota Category',
(select general_rate from official_tariffs where official_tariffs.hts_code = tariff_records.hts_2 and official_tariffs.country_id = classifications.country_id) as 'Tariff - 2 - General Rate',
tariff_records.hts_3 as 'Tariff - HTS Code 3',
(select category from official_quotas where official_quotas.hts_code = tariff_records.hts_3 and official_quotas.country_id = classifications.country_id LIMIT 1) as 'Tariff - 3 - Quota Category',
(select general_rate from official_tariffs where official_tariffs.hts_code = tariff_records.hts_3 and official_tariffs.country_id = classifications.country_id) as 'Tariff - 3 - General Rate',"
    self.class.cdef_range.each do |cdef|
      q << cd_s(@cdefs[cdef])+","
    end
    q << "tariff_records.line_number as 'Tariff - HTS Row'"
    q << "
FROM products
INNER JOIN classifications ON classifications.product_id = products.id
INNER JOIN countries on classifications.country_id = countries.id AND countries.iso_code = 'IT'
INNER JOIN tariff_records ON tariff_records.classification_id = classifications.id AND length(tariff_records.hts_1) > 0"
    # If we have a custom where, then don't add the need_sync join clauses.
    if @custom_where.blank?
      q << "\n#{Product.need_sync_join_clause(sync_code)} "
      q << "\nWHERE #{Product.need_sync_where_clause()}"
    else
      q << "\n#{@custom_where}"
    end

    if @max_results
      q << " ORDER BY products.updated_at ASC LIMIT #{@max_results}"
    end
    q
  end

  def self.cdefs
    [:lin_number, :csm_numbers, :season, :product_area, :msl_board_number, :fiber_content, :clean_fiber_content, :knit_woven] + cdef_range
  end

  def self.cdef_range
    [:stitch_count_vertical, :stitch_count_horizontal, :grams_square_meter, :knit_type, :type_of_bottom, :functional_neck_closure, :significantly_napped, :back_type, :defined_armholes,
     :strap_width, :pass_water_resistant_test, :type_of_coating, :padding_or_filling, :meets_down_requirments, :tightening_at_waist, :denim, :denim_color, :corduroy, :shearling, :total_back_panels,
     :short_fall_above_knee, :mesh_lining, :full_elastic_waistband, :full_functional_drawstring, :cover_crown_of_head, :wholly_or_partially_braid, :yarn_dyed, :colors_in_warp_weft, :piece_dyed,
     :printed, :solid, :ounces_sq_yd, :size_scale, :type_of_fabric, :weight_of_fabric, :form_fitting_or_loose_fitting, :functional_open_fly, :fly_covered, :tightening_at_cuffs,
     :embellishments_or_ornamentation, :sizing, :sold_in_sleepwear_dept, :pcs_in_set, :sold_as_set, :footwear_upper, :footwear_outsole, :welted, :cover_the_ankle, :length_cm, :width_cm,
     :height_cm, :secure_closure, :closure_type, :multiple_compartment, :fourchettes_for_gloves, :lined_for_gloves, :seamed, :components, :cost_of_component, :weight_of_components,
     :material_content_of_posts_earrings, :filled, :type_of_fill, :coated, :semi_precious, :semi_precious_type, :telescopic_shaft, :unit_price, :vendor_code, :country_of_origin, :fish_wildlife,
     :common_name_1, :scientific_name_1, :fish_wildlife_origin_1, :fish_wildlife_source_1, :royalty_percentage, :chart_comments, :binding_ruling_number, :binding_ruling_type, :mid, :fda_product_code,
     :effective_date, :price_uom, :special_program_indicator, :cvd_case, :add_case, :ptp_code, :terms_of_sale]
  end

end; end; end
