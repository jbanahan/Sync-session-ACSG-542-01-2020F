require 'open_chain/integration_client_parser'
require 'open_chain/mutable_boolean'
require 'open_chain/custom_handler/polo/polo_custom_definition_support'

module OpenChain; module CustomHandler; module Polo; class PoloGlobalFrontEndProductParser
  include OpenChain::IntegrationClientParser
  include OpenChain::CustomHandler::Polo::PoloCustomDefinitionSupport

  def self.parse_file data, log, opts = {}
    self.new.parse data, User.integration, opts[:key]
  end

  def parse data, user, file
    # \007 turns the bell character into the quote char, which essentially turns off csv
    # quoting, but also enables the file to have "s in the file without turning on ruby's
    # csv quote handling and throwing errors.
    CSV.parse(data, {col_sep: "|", quote_char: "\007"}) do |row|
      parse_line row, user, file
    end
  end

  def parse_line row, user, file
    return if row[0].blank?

    p = nil
    find_or_create_product(string_value(row[0])) do |product|
      p = parse_product product, row, user, file
    end
    p
  end

  def find_or_create_product style
    product = nil
    Lock.acquire("Product-#{style}") do 
      product = Product.where(unique_identifier: style).first_or_create!
    end

    Lock.db_lock(product) do 
      yield product
    end
  end

  def parse_product product, row, user, file
    # Used to track if any custom values changed or not..we'll not save unless something in the product changes.
    changed = MutableBoolean.new false
    set_custom_value(product, :digit_style_6, string_value(row[2]), changed)
    set_custom_value(product, :season, string_value(row[3]), changed)
    set_custom_value(product, :msl_board_number, string_value(row[4]), changed)
    set_custom_value(product, :sap_brand_name, string_value(row[5]), changed)
    set_custom_value(product, :rl_merchandise_division_description, string_value(row[6]), changed)
    set_custom_value(product, :gender_desc, string_value(row[7]), changed)
    set_custom_value(product, :product_category, string_value(row[8]), changed)
    set_custom_value(product, :product_class_description, string_value(row[9]), changed)
    set_custom_value(product, :ax_subclass, string_value(row[10]), changed)
    set_custom_value(product, :rl_short_description, string_value(row[12]), changed)
    set_custom_value(product, :rl_long_description, string_value(row[13]), changed)
    set_custom_value(product, :merchandising_fabrication, string_value(row[14]), changed)
    set_custom_value(product, :heel_height, string_value(row[15]), changed)
    set_custom_value(product, :material_status, material_status_value(row[16]), changed)
    set_custom_value(product, :ax_export_status, ax_export_status_value(row[17]), changed)

    if changed.value
      product.save!
      product.create_snapshot user, nil, file
      return product
    else
      # AX product generator will resend this record. Each additional generator
      # requiring this behavior will need its own flag
      product.update_custom_value! cdefs[:ax_updated_without_change], true
      return nil
    end
  end


  def cdefs
    @cdefs ||= self.class.prep_custom_definitions([:digit_style_6, :season, :msl_board_number, :sap_brand_name, :rl_merchandise_division_description, 
      :gender_desc, :product_category, :product_class_description, :ax_subclass, :rl_short_description, :rl_long_description, 
      :merchandising_fabrication, :heel_height, :material_status, :ax_export_status, :ax_updated_without_change
    ])
  end

  def set_custom_value product, cdef_uid, value, changed
    cd = cdefs[cdef_uid]
    existing = product.custom_value(cd)
    if existing != value
      product.find_and_set_custom_value cd, value
      changed.value = true
    end
    nil
  end

  def material_status_value value
    # Use the one of list value defined in the field validator rule to validate the incoming data
    cdef_validation(:material_status, value)
  end

  def ax_export_status_value value
    # Use the one of list value defined in the field validator rule to validate the incoming data
    cdef_validation(:ax_export_status, value)
  end

  def cdef_validation cdef_uid, value
    value = string_value(value)
    fvr = field_validator_rule(cdef_uid)
    return value if fvr.nil?

    errors = fvr.validate_input(value)
    (errors.nil? || errors.length == 0) ? value : nil
  end

  def string_value value
    value.to_s.strip
  end

  # This is mainly done to make testing the validation easier
  def field_validator_rule uid
    # Interestingly, if you just do `field_validator_rules.first`, every single call to this method executes a
    # sql query...as opposed to the below, which just loads the rules the first time and then uses
    # the in-memory list every other time after that.
    cdefs[uid].field_validator_rules.to_a[0]
  end

end; end; end; end
