require 'open_chain/custom_handler/under_armour/under_armour_custom_definition_support'
require 'open_chain/xl_client'
module OpenChain; module CustomHandler; module UnderArmour; class UaStyleColorFactoryParser
include OpenChain::CustomHandler::UnderArmour::UnderArmourCustomDefinitionSupport
  def initialize custom_file
    @custom_file = custom_file
  end

  def can_view? user
    # this style of coding is more lines of code than connecting everything in
    # one conditional, but it's more readable and easier to edit if the rules
    # change later - Brian
    return false unless user.company.master?
    return false unless user.edit_trade_preference_programs?
    return false unless user.edit_variants?
    return false unless MasterSetup.get.custom_feature?('UA-TPP')
    return true
  end

  def process user
    raise "User does not have permission to process this file." unless self.can_view?(user)
    h = Hash.new
    collect_rows do |row|
      update_data_hash h, row
    end
    process_data_hash h, user
    user.messages.create(subject:'Style/Color/Region Parser Complete',body:'Your processing job has completed.')
    return true
  end

  def collect_rows
    OpenChain::XLClient.new_from_attachable(@custom_file).all_row_values(0,0,500) {|row| yield row}
  end

  def process_data_hash h, user
    h.each {|k,v| update_product(v, user)}
  end

  def update_data_hash h, row
    return unless row.length == 11
    style = get_style(row)
    return if style.nil?
    country_code = get_country_code(row)
    color = get_color(row)
    name = row[1]
    division = row[4].to_s.strip
    season = row[5].to_s.strip.upcase
    style_hash = h[style]
    if !style_hash
      style_hash = {colors:{},seasons:[]}
      h[style] = style_hash
    end
    style_hash[:style] = style
    style_hash[:name] = name
    style_hash[:division] = division
    style_hash[:seasons] << season
    style_hash[:seasons].uniq!
    countries = style_hash[:colors][color]
    if !countries
      countries = []
      style_hash[:colors][color] = countries
    end
    countries << country_code
    countries.uniq!
    nil
  end

  def update_product h, user
    @cdefs ||= self.class.prep_custom_definitions [:colors,:prod_export_countries,:prod_seasons,:var_export_countries]
    ActiveRecord::Base.transaction do
      byebug if h[:style].blank?
      p = Product.where(unique_identifier:h[:style]).first_or_create!
      p.name = h[:name]
      p.division_id = get_division_id(h[:division])
      cv_seasons = p.get_custom_value(@cdefs[:prod_seasons])
      cv_seasons.value = merge_custom_value(cv_seasons,h[:seasons])
      cv_colors = p.get_custom_value(@cdefs[:colors])
      cv_colors.value = merge_custom_value(cv_colors,h[:colors].keys)
      cv_countries = p.get_custom_value(@cdefs[:prod_export_countries])
      cv_countries.value = merge_custom_value(cv_countries,h[:colors].values.flatten)
      raise "You cannot edit product #{p.unique_identifier}." unless p.can_edit?(user)
      p.save!
      update_variants(p,h,user)
      p.create_snapshot user
    end
  end

  #####
  # helpers
  #####
  def get_style row
    style = row[0].to_s.gsub(/\.0$/,'') #clean up numbers for style string
    return nil if style=='Style'
    raise "Style (#{style}) must be a 7 digit number." unless style.match(/^[0-9]{7}$/)
    style
  end
  private :get_style

  def get_country_code row
    @country_codes ||= Country.pluck(:iso_code)
    iso = row[9].strip
    if !@country_codes.include?(iso.upcase)
      raise "Country code #{iso} is not found."
    end
    iso
  end
  private :get_country_code

  def get_color row
    color = row[2].to_s.split('-').last
    raise "Color portion of style-color (#{row[2]}) must be 3 digits." unless color.match(/^[0-9]{3}$/)
    color
  end
  private :get_color

  def update_variants p, h, user
    h[:colors].each do |color,countries|
      v = p.variants.where(variant_identifier:color).first_or_create!
      cv_countries = v.get_custom_value(@cdefs[:var_export_countries])
      cv_countries.value = merge_custom_value(cv_countries,countries)
      raise "You cannot edit variant #{v.variant_identifier} for product #{p.unique_identifier}." unless v.can_edit?(user)
      v.save!
    end
  end
  private :update_variants

  def merge_custom_value cv, ary
    s = cv.value
    s = "" if s.blank?
    base = s.lines.map(&:strip)
    (base+ary).compact.map(&:upcase).uniq.sort.join("\n")
  end
  private :merge_custom_value

  def get_division_id name
    @division_cache ||= {}
    d = @division_cache[name.upcase]
    if d.nil?
      d = Company.where(master:true).first.divisions.where(name:name).first_or_create!
      @division_cache[name.upcase] = d
    end
    d.id
  end
  private :get_division_id

end; end; end; end
