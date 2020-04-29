require 'open_chain/custom_handler/under_armour/under_armour_custom_definition_support'
require 'open_chain/xl_client'
module OpenChain; module CustomHandler; module UnderArmour; class UaStyleColorRegionParser
  include OpenChain::CustomHandler::UnderArmour::UnderArmourCustomDefinitionSupport

  REGION_MAP ||= {
    'US' => 'US',
    'AUSTRALIA' => 'AU',
    'BRAZIL' => 'BR',
    'CANADA' => 'CA',
    'CHILE' => 'CL',
    'MEXICO' => 'MX',
    'NEW ZEALAND' => 'NZ',
    'UK' => 'GB',
    'GREATER CHINA'=>'CN',
    'HONG KONG' => 'HK',
    'TAIWAN' => 'TW',
    'EUROPE' => 'NL',
    'SOUTHEAST ASIA' => 'SG',
    'LATIN AMERICA' => 'PA',
    'JAPAN' => 'JP',
    "KOREA" => "KR",
    "ARGENTINA" => "AR",
    "RUSSIA" => "RU"
  }

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
    user.messages.create(subject:'Style/Color/Region Parser Complete', body:'Your processing job has completed.')
    return true
  end

  def collect_rows
    OpenChain::XLClient.new_from_attachable(@custom_file).all_row_values(chunk_size: 500) {|row| yield row}
  end

  def update_data_hash h, row
    row.pop while row.last.nil? && row.size > 0
    return unless row.length == 7
    style = row[0].to_s.gsub(/\.0$/, '') # clean up numbers for style string
    return if style=='Style'
    raise "Style (#{style}) must be a 7 digit number." unless style.match(/^[0-9]{7}$/)
    import_country = REGION_MAP[row[6].upcase]
    raise "Region (#{row[6].upcase}) not found." if import_country.blank?
    style_hash = h[style]
    if style_hash.nil?
      h[style] = {colors:{}, seasons:[]}
      style_hash = h[style]
    end
    style_hash[:style] = style
    style_hash[:name] = row[1]
    color = get_color(row)
    return if color.nil?
    color_countries = style_hash[:colors][color]
    if color_countries.nil?
      style_hash[:colors][color] = []
      color_countries = style_hash[:colors][color]
    end
    color_countries << import_country
    color_countries.uniq!
    style_hash[:division] = row[4]
    style_hash[:seasons] << row[5]
    style_hash[:seasons].uniq!
    nil
  end

  def process_data_hash h, user
    h.each {|k, v| update_product(v, user)}
  end

  def update_product h, user
    @cdefs ||= self.class.prep_custom_definitions [:colors, :prod_import_countries, :prod_seasons, :var_import_countries]
    ActiveRecord::Base.transaction do
      p = Product.where(unique_identifier:h[:style]).first_or_create!
      p.name = h[:name]
      p.division_id = get_division_id(h[:division])
      cv_seasons = p.get_custom_value(@cdefs[:prod_seasons])
      cv_seasons.value = merge_custom_value(cv_seasons, h[:seasons])
      cv_colors = p.get_custom_value(@cdefs[:colors])
      cv_colors.value = merge_custom_value(cv_colors, h[:colors].keys)
      cv_countries = p.get_custom_value(@cdefs[:prod_import_countries])
      cv_countries.value = merge_custom_value(cv_countries, h[:colors].values.flatten)
      raise "You cannot edit product #{p.unique_identifier}." unless p.can_edit?(user)
      p.save!
      update_variants(p, h, user)
      p.create_snapshot user
    end
  end


  #####
  # product updating helper methods
  #####

  def update_variants p, h, user
    h[:colors].each do |color, countries|
      v = p.variants.where(variant_identifier:color).first_or_create!
      cv_countries = v.get_custom_value(@cdefs[:var_import_countries])
      cv_countries.value = merge_custom_value(cv_countries, countries)
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
    return nil if name.blank?

    @division_cache ||= {}
    d = @division_cache[name.upcase]
    if d.nil?
      d = Company.where(master:true).first.divisions.where(name:name).first_or_create!
      @division_cache[name.upcase] = d
    end
    d.id
  end
  private :get_division_id

  def get_color row
    color = row[2].to_s.split('-').last
    # first check to make sure the color is 3 digits
    # then if it isn't, check if it has a letter and is 3 characters, which are valid formats but should be ignored.
    # finally fail if it doesn't match either that all values are digits
    return color if color.match(/^[0-9]{3}$/)
    return nil if color.match(/^[a-zA-Z0-9]{3}$/)
    raise "Color portion of style-color (#{row[2]}) must be 3 digits."
  end
  private :get_color

end; end; end; end
