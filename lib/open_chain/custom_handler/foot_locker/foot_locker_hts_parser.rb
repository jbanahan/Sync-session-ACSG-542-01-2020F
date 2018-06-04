require 'open_chain/custom_handler/vfitrack_custom_definition_support'
require 'open_chain/integration_client_parser'

module OpenChain; module CustomHandler; module FootLocker; class FootLockerHtsParser
  include VfitrackCustomDefinitionSupport
  extend OpenChain::IntegrationClientParser

  FOOT_LOCKER_CUSTOMER_NUMBER ||= "FOOLO"

  def self.integration_folder
    ["www-vfitrack-net/footlocker_hts", "www-vfitrack-net/footlocker_hts"]
  end

  def self.parse csv, opts={}
    self.new.process_file csv, opts[:key], opts
  end

  def process_file csv, file_name, opts={}
    user = User.integration
    foot_locker_company = Company.where("alliance_customer_number = ? ", FOOT_LOCKER_CUSTOMER_NUMBER).first

    unless foot_locker_company
      raise "Unable to process Foot Locker HTS file because no company record could be found with Alliance Customer number '#{FOOT_LOCKER_CUSTOMER_NUMBER}'."
    end

    begin
      # Let's be a bit paranoid and set our quote character since the CSV does not contain quotes.
      CSV.parse(csv, {quote_char: "\x00"}) do |row|
        next if row.blank?

        product = {}
        product[:division] = is_canada?(row[0]) ? 'CA' : 'US'
        product[:article] = row[1]
        product[:description] = row[2]
        product[:customs_description] = row[3]
        product[:hts] = clean_up_hts_number(row[4])
        product[:coo] = row[8]
        product[:season] = row[5]
        save_product(product, foot_locker_company, user, file_name)
      end
    end
  end

  def save_product(product, company, user, file_name)
    uid = "#{FOOT_LOCKER_CUSTOMER_NUMBER}-#{product[:article]}"
    p = nil
    Lock.acquire("Product-#{uid}") do
      p = Product.where(importer_id: company.id, unique_identifier: uid).first_or_create!
    end

    Lock.db_lock(p) do
      changed = false
      p.name = product[:description]
      if p.custom_value(cdefs[:prod_part_number]) != product[:article]
        p.find_and_set_custom_value(cdefs[:prod_part_number], product[:article])
        changed = true
      end

      if p.custom_value(cdefs[:prod_country_of_origin]) != product[:coo]
        p.find_and_set_custom_value(cdefs[:prod_country_of_origin], product[:coo])
        changed = true
      end

      hts_country = find_hts_country(product[:division])
      if p.hts_for_country(hts_country) != product[:hts]
        p.update_hts_for_country(hts_country, product[:hts])
        changed = true
      end

      classification = p.classifications.find {|c| c.country_id == hts_country.id }
      if classification.custom_value(cdefs[:class_customs_description]) != product[:customs_description]
        p.find_and_set_custom_value(cdefs[:class_customs_description], product[:customs_description])
        changed = true
      end

      if p.custom_value(cdefs[:prod_season]) != product[:season]
        p.find_and_set_custom_value(cdefs[:prod_season], product[:season])
        changed = true
      end

      if p.changed? || changed
        p.save!
        p.create_snapshot user, nil, file_name
      end
    end
  end

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions([:prod_season, :prod_part_number, :prod_country_of_origin, :class_customs_description])
  end

  def find_hts_country(division)
    division == 'CA' ? ca : us
  end

  def us
    @us_country ||= Country.where(iso_code: "US").first
    raise "USA Country not found." if @us_country.nil?
    @us_country
  end

  def ca
    @ca_country ||= Country.where(iso_code: "CA").first
    raise "CA Country not found." if @ca_country.nil?
    @ca_country
  end

  def clean_up_hts_number(hts_number)
    return unless hts_number.present?
    hts_number.gsub('.', '')
  end

  def is_canada?(division)
    ['73', '76', '77' ].include?(division)
  end
end; end; end; end
