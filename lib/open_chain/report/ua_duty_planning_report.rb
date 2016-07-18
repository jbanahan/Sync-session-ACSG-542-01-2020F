require 'csv'
require 'open_chain/s3'
require 'open_chain/custom_handler/under_armour/under_armour_custom_definition_support'

module OpenChain; module Report; class UaDutyPlanningReport
  include OpenChain::CustomHandler::UnderArmour::UnderArmourCustomDefinitionSupport
  def self.permission? user
    user.view_products? && user.company.master? && MasterSetup.get.custom_feature?('UA-TPP')
  end
  def self.run_report user, params
    raise "User does not have permission to run report." unless self.permission?(user)
    caches = {
      official_tariffs: {},
      trade_lanes: {},
      countries: {}
    }
    cdefs = prep_custom_definitions [:prod_export_countries,:import_countries,:prod_seasons,:expected_duty_rate]
    query_opts = params.with_indifferent_access
    raise "Must have style list or season code." if query_opts[:season].blank? && query_opts[:style_s3_path].blank?
    f = Tempfile.open(['ua_duty_planning','csv'])
    begin
      f << ['Country of Origin','Region of Destination','Style','','HTS Code','','Duty'].to_csv
      products = find_products(user, query_opts, cdefs)
      products.each do |p|
        write_product f, p, cdefs, caches
      end
    ensure
      f.flush
    end
    OpenChain::S3.delete(OpenChain::S3.bucket_name,query_opts[:style_s3_path]) unless query_opts[:style_s3_path].blank?
    return f
  end

  def self.write_product f, p, cdefs, caches
    product_rows = []
    import_countries = p.get_custom_value(cdefs[:import_countries]).value
    export_countries = p.get_custom_value(cdefs[:prod_export_countries]).value
    p.classifications.each do |cls|
      next unless import_countries.match(cls.country.iso_code)
      tr = cls.tariff_records.first
      hts_code = tr.hts_1.hts_format
      export_countries.split("\n").each do |export_iso|
        next unless export_iso.length == 2
        next if export_iso == cls.country.iso_code
        product_rows << [export_iso,cls.country.iso_code,p.unique_identifier,p.name,hts_code,hts_code,output_rate(caches,tr,export_iso,cdefs)].to_csv
      end
    end
    product_rows.sort.each {|pr| f << pr}
  end

  def self.output_rate caches, tr, export_iso, cdefs
    r = nil
    classification_override = tr.classification.get_custom_value(cdefs[:expected_duty_rate]).value
    if !classification_override.nil?
      r = BigDecimal(classification_override,2)
    else
      ot = find_official_tariff caches[:official_tariffs], tr
      if ot
        trade_lane = find_trade_lane(caches,tr.classification.country,export_iso)
        if trade_lane
          tpp_rate = find_tpp_rate(trade_lane,ot)
          if tpp_rate
            r = tpp_rate
          end
        end
        if r.nil?
          crd = ot.common_rate_decimal
          if crd
            r = BigDecimal(crd*100.00,2)
            if trade_lane && trade_lane.tariff_adjustment_percentage
              r = r + (trade_lane.tariff_adjustment_percentage)
            end
          end
        end
      end
    end
    r.nil? ? '' : r.to_s('F')
  end

  def self.find_tpp_rate trade_lane, official_tariff
    rates = []
    trade_lane.trade_preference_programs.each do |tpp|
      override = tpp.tpp_hts_overrides.where('tpp_hts_overrides.hts_code = LEFT(?,length(tpp_hts_overrides.hts_code))',official_tariff.hts_code).order('length(tpp_hts_overrides.hts_code) DESC').pluck(:rate).first
      if override
        rates << override
      else
        next if tpp.tariff_identifier.blank? || official_tariff.special_rate_key.blank?
        rate = SpiRate.where(
          special_rate_key:official_tariff.special_rate_key,
          country_id:official_tariff.country_id,
          program_code:tpp.tariff_identifier
        ).pluck(:rate).first
        if rate
          rate = BigDecimal(rate*100.00,2)
          if tpp.tariff_adjustment_percentage
            rate = rate + tpp.tariff_adjustment_percentage
          end
          rates << rate
        end
      end
    end
    rates.compact.sort.first
  end

  def self.find_trade_lane caches, import_country, export_iso
    export_country = find_country(caches[:countries],export_iso)
    tl_key = "#{import_country.id}-#{export_country.id}"
    tl = caches[:trade_lanes][tl_key]
    if !tl
      tl = TradeLane.where(destination_country_id:import_country.id,origin_country_id:export_country.id).first
      tl = 'X' if tl.nil?
      caches[:trade_lanes][tl_key] = tl
    end
    return tl=='X' ? nil : tl
  end
  def self.find_country cache, iso
    c = cache[iso]
    if !c
      c = Country.find_by_iso_code iso
      cache[iso] = c
    end
    c
  end

  def self.find_official_tariff cache, tariff_record
    hts = tariff_record.hts_1
    return nil if hts.blank?
    country_id = tariff_record.classification.country_id
    key = "#{country_id}-#{hts}"
    ot = cache[key]
    if ot.blank?
      ot = OfficialTariff.where(country_id:country_id,hts_code:hts).first
      cache[key] = ot
    end
    ot
  end

  def self.find_products user, query_opts, cdefs
    p = Product.includes([:custom_values,:classifications=>[:tariff_records,:country]])
    p = Product.search_secure user, p
    if !query_opts[:style_s3_path].blank?
      uids = get_uids_from_s3(query_opts[:style_s3_path])
      p = p.where("products.unique_identifier IN (?)",uids)
    elsif !query_opts[:season].blank?
      p = p.where("products.id IN (SELECT customizable_id FROM custom_values WHERE custom_definition_id = #{cdefs[:prod_seasons].id} AND text_value LIKE ?)","%#{query_opts[:season]}%")
    else
      raise "No styles or season provided."
    end
    p = p.where('tariff_records.line_number = (SELECT min(line_number) FROM tariff_records WHERE tariff_records.classification_id = classifications.id)')
    p = p.where('length(tariff_records.hts_1)>1')
    p
  end

  def self.get_uids_from_s3 path
    data = OpenChain::S3.get_data(OpenChain::S3.bucket_name,path)
    data.lines.map(&:strip)
  end
end; end; end
