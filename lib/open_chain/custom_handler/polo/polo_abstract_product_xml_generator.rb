require 'open_chain/custom_handler/product_generator'
require 'open_chain/xml_builder'
require 'open_chain/custom_handler/polo/polo_custom_definition_support'

#
# This is a abstract base class for sending Polo XML product data to another organization.
# 
# The extending class must merely implement the sync_code and ftp_credentials methods to use this class.
#
module OpenChain; module CustomHandler; module Polo; class PoloAbstractProductXmlGenerator < OpenChain::CustomHandler::ProductGenerator
  include OpenChain::XmlBuilder
  include OpenChain::CustomHandler::Polo::PoloCustomDefinitionSupport

  def self.run_schedulable opts = {}
    g = self.new opts
    begin
      # Sync only does 500 products at a time now, so keep running the send
      # until we get a file output w/ zero lines (sync_xml returns a nil file in this case)
      f = g.sync_xml
      g.ftp_file f unless f.nil?
    end while !f.nil?
  end

  def write_row_to_xml parent, counter, row
    el = add_element(parent, "Product")

    p = Product.where(id: row[0]).includes([{classifications: [:country, :tariff_records, :custom_values]}, :custom_values]).first
    return nil unless p

    add_element el, "Style", p.unique_identifier
    add_element el, "FibreContent", p.custom_value(cdefs[:fiber_content])
    add_element el, "LongDesc", p.name
    add_element el, "ShortDesc", p.custom_value(cdefs[:rl_short_description])
    add_element el, "KnitWoven", p.custom_value(cdefs[:knit_woven])
    add_element el, "KnitType", p.custom_value(cdefs[:knit_type])
    add_element el, "BottomType", p.custom_value(cdefs[:type_of_bottom])
    add_element el, "FuncNeckOpening", boolean(p.custom_value(cdefs[:functional_neck_closure]))
    add_element el, "SignifNaP", boolean(p.custom_value(cdefs[:significantly_napped]))
    add_element el, "WaterTest ", p.custom_value(cdefs[:pass_water_resistant_test])
    add_element el, "CoatingType", p.custom_value(cdefs[:type_of_coating])
    add_element el, "PaddOrFill", p.custom_value(cdefs[:padding_or_filling])
    add_element el, "Down", boolean(p.custom_value(cdefs[:meets_down_requirments]))
    add_element el, "WaistType", p.custom_value(cdefs[:tightening_at_waist])
    add_element el, "Denim", p.custom_value(cdefs[:denim])
    add_element el, "DenimCol", p.custom_value(cdefs[:denim_color])
    add_element el, "Corduroy", boolean(p.custom_value(cdefs[:corduroy]))
    add_element el, "BackPanels", p.custom_value(cdefs[:total_back_panels])
    add_element el, "ShtFallAboveKnee ", boolean(p.custom_value(cdefs[:short_fall_above_knee]))
    add_element el, "MeshLining ", boolean(p.custom_value(cdefs[:mesh_lining]))
    add_element el, "ElasticWaist ", boolean(p.custom_value(cdefs[:full_elastic_waistband]))
    add_element el, "FunctionalDrawstring ", boolean(p.custom_value(cdefs[:full_functional_drawstring]))
    add_element el, "CoverCrownHead ", boolean(p.custom_value(cdefs[:cover_crown_of_head]))
    add_element el, "WholePartialBraid ", p.custom_value(cdefs[:wholly_or_partially_braid])
    add_element el, "DyedType ", p.custom_value(cdefs[:yarn_dyed])
    add_element el, "WarpW", p.custom_value(cdefs[:colors_in_warp_weft])
    add_element el, "SizeScale", p.custom_value(cdefs[:size_scale])
    add_element el, "FabricType", p.custom_value(cdefs[:type_of_fabric])
    add_element el, "FuncFly ", boolean(p.custom_value(cdefs[:functional_open_fly]))
    add_element el, "TightningCuffs ", boolean(p.custom_value(cdefs[:tightening_at_cuffs]))
    add_element el, "Royalty", p.custom_value(cdefs[:royalty_percentage])
    add_element el, "FDAIndic", p.custom_value(cdefs[:prod_fda_indicator])
    
    us_classification = p.classifications.find {|c| c.country&.iso_code == "US" }
    if us_classification
      fda_code = us_classification.custom_value(cdefs[:fda_product_code])
      set_type = us_classification.custom_value(cdefs[:set_type])
    end

    add_element el, "FDAProdCode", fda_code
    add_element el, "SetType", set_type

    p.classifications.each do |c|
      next if c.country.nil?

      c.tariff_records.each do |t|
        hts = add_element el, "HTS"
        add_element hts, "HTSCountry", c.country.iso_code
        add_element hts, "HTSTariffCode", t.hts_1
        ot = official_tariff(c, t)
        add_element hts, "HTSQuotaCategory", ot&.official_quota&.category
        add_element hts, "HTSGeneralRate", ot&.common_rate
      end
    end

    stitch = add_element el, "StitchCountWeight"
    add_element stitch, "TwocmVert", p.custom_value(cdefs[:stitch_count_vertical])
    add_element stitch, "TwocmHori", p.custom_value(cdefs[:stitch_count_horizontal])
    add_element stitch, "GmSquM", p.custom_value(cdefs[:grams_square_meter])
    add_element stitch, "OzSqYd", p.custom_value(cdefs[:ounces_sq_yd])
    add_element stitch, "WeightFabric", p.custom_value(cdefs[:weight_of_fabric])

    sleepware = add_element el, "Sleepwear"
    add_element sleepware, "FormLooseFit", p.custom_value(cdefs[:form_fitting_or_loose_fitting])
    add_element sleepware, "FlyOpenPlacket", boolean(p.custom_value(cdefs[:fly_covered]))
    add_element sleepware, "EmbellishOrnament", boolean(p.custom_value(cdefs[:embellishments_or_ornamentation]))
    add_element sleepware, "Sizing", p.custom_value(cdefs[:sizing])
    add_element sleepware, "SleepwearDept", boolean(p.custom_value(cdefs[:sold_in_sleepwear_dept]))
    add_element sleepware, "PcsinSet", p.custom_value(cdefs[:pcs_in_set])
    add_element sleepware, "SoldasSet", boolean(p.custom_value(cdefs[:sold_as_set]))

    footwear = add_element el, "Footwear"
    add_element footwear, "Welted", boolean(p.custom_value(cdefs[:welted]))
    add_element footwear, "CoverAnkle", boolean(p.custom_value(cdefs[:cover_the_ankle]))
    add_element footwear, "JapLeather", boolean(p.custom_value(cdefs[:japanese_leather_definition]))

    hbag = add_element el, "HandbagsScarves"
    add_element hbag, "Lengthcm", p.custom_value(cdefs[:length_cm])
    add_element hbag, "Widthcm", p.custom_value(cdefs[:width_cm])
    add_element hbag, "Heightcm", p.custom_value(cdefs[:height_cm])
    add_element hbag, "Lengthin", p.custom_value(cdefs[:length_in])
    add_element hbag, "Widthin", p.custom_value(cdefs[:width_in])
    add_element hbag, "Heightin", p.custom_value(cdefs[:height_in])
    add_element hbag, "StrapWidth", p.custom_value(cdefs[:strap_width])
    add_element hbag, "SecureClosure", boolean(p.custom_value(cdefs[:secure_closure]))
    add_element hbag, "ClosureType", p.custom_value(cdefs[:closure_type])
    add_element hbag, "MultipleCompart", boolean(p.custom_value(cdefs[:multiple_compartment]))

    gloves = add_element el, "Gloves"
    add_element gloves, "GlovesFourchettes", boolean(p.custom_value(cdefs[:fourchettes_for_gloves]))
    add_element gloves, "GlovesLined", boolean(p.custom_value(cdefs[:lined_for_gloves]))
    add_element gloves, "Seamed", boolean(p.custom_value(cdefs[:seamed]))

    jewelry = add_element el, "Jewelry"
    add_element jewelry, "Components", p.custom_value(cdefs[:components])
    add_element jewelry, "CostComponents", p.custom_value(cdefs[:cost_of_component])
    add_element jewelry, "WeightComponents", p.custom_value(cdefs[:weight_of_components])
    add_element jewelry, "CoatedFilledPlated", p.custom_value(cdefs[:coated_filled_plated])
    add_element jewelry, "TypeCoatedFilledPlated", p.custom_value(cdefs[:type_coated_filled_plated])
    add_element jewelry, "PreciousSemiPrecious", p.custom_value(cdefs[:precious_semi_precious])

    umbrella = add_element el, "Umbrella"
    add_element umbrella, "TelescopicShaft", boolean(p.custom_value(cdefs[:telescopic_shaft]))

    sanitation = add_element el, "Sanitation"
    add_element sanitation, "EUSanitation", boolean(p.custom_value(cdefs[:eu_sanitation_certificate]))
    add_element sanitation, "JapanSanitation", boolean(p.custom_value(cdefs[:japan_sanitation_certificate]))
    add_element sanitation, "KoreaSanitaion", boolean(p.custom_value(cdefs[:korea_sanitation_certificate]))

    nil
  end

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions([:fiber_content, :rl_short_description, :knit_woven, :knit_type, :type_of_bottom, 
      :functional_neck_closure, :significantly_napped, :pass_water_resistant_test, :type_of_coating, :padding_or_filling, :meets_down_requirments, 
      :tightening_at_waist, :denim, :denim_color, :corduroy, :total_back_panels, :short_fall_above_knee, :mesh_lining, :full_elastic_waistband, 
      :full_functional_drawstring, :cover_crown_of_head, :wholly_or_partially_braid, :yarn_dyed, :colors_in_warp_weft, :size_scale, :type_of_fabric, 
      :functional_open_fly, :tightening_at_cuffs, :royalty_percentage, :prod_fda_indicator, :fda_product_code, :set_type, :stitch_count_vertical, 
      :stitch_count_horizontal, :grams_square_meter, :ounces_sq_yd, :weight_of_fabric, :form_fitting_or_loose_fitting, :fly_covered, 
      :embellishments_or_ornamentation, :sizing, :sold_in_sleepwear_dept, :pcs_in_set, :sold_as_set, :welted, :cover_the_ankle, :japanese_leather_definition, 
      :length_cm, :width_cm, :height_cm, :length_in, :width_in, :height_in, :strap_width, :secure_closure, :closure_type, :multiple_compartment, 
      :fourchettes_for_gloves, :lined_for_gloves, :seamed, :components, :cost_of_component, :weight_of_components, :coated_filled_plated, 
      :type_coated_filled_plated, :precious_semi_precious, :telescopic_shaft, :eu_sanitation_certificate, :japan_sanitation_certificate, 
      :korea_sanitation_certificate])
  end

  def boolean v
    ["Y", "1", "T"].include?(v.to_s.upcase[0]) ? "Y" : "N"
  end

  def us
    @us ||= Country.where(iso_code: "US").first
  end

  def official_tariff classification, tariff_record
    @official_tariffs ||= Hash.new do |h, k|
      h[k] = OfficialTariff.where(country_id: k[0], hts_code: k[1]).first
    end

    @official_tariffs[[classification.country_id, tariff_record.hts_1]]
  end

  def max_products
    500
  end

  def query
    # First id is stripped off, but we want it sent to the xml method so add it twice to the query
    q = "SELECT products.id, products.id FROM products products #{Product.need_sync_join_clause(sync_code)} "
    if custom_where.blank?
      q += "WHERE #{Product.need_sync_where_clause} "
    else
      q += "WHERE #{custom_where} "
    end
    q += "ORDER BY products.updated_at "
    q += "LIMIT #{max_products}"

    q
  end

end; end; end; end;