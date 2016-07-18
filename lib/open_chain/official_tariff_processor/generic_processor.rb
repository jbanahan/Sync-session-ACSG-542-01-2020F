module OpenChain; module OfficialTariffProcessor; class GenericProcessor
  def self.process official_tariff
    country = official_tariff.country
    cid = country.id
    srk = official_tariff.special_rate_key
    # do nothing if the rates are already built for this key
    return unless SpiRate.where(special_rate_key:srk,country_id:cid).empty?

    rates = parse_spi(parse_data_for(country),official_tariff.special_rates)
    return if rates.nil?
    rates.each do |rate_data|
      SpiRate.create!(special_rate_key:srk,
        country_id:cid,program_code:rate_data[:program_code],
        rate:rate_data[:amount],rate_text:rate_data[:text])
    end
  end

  def self.parse_spi parse_data, spi_raw
    spi = spi_raw
    if parse_data[:replaces]
      parse_data[:replaces].each {|k,v| spi = spi.gsub(k,v)}
    end
    results = spi.scan parse_data[:parser]

    if results.length == 0
      parse_data[:exceptions].each do |r|
        return nil if spi.match(r)
      end
    end
    raise "Invalid spi found for '#{spi}'." unless results.length > 0

    programs = []

    results.each do |r|
      raise "Invalid parse expression: #{spi} - (Bad elements: #{r}).  Each matched SPI expression should return exactly 2 non-blank match values." unless r.length == 2 && !r.any?(&:blank?)
      rate_text = r[0].strip
      r[1].split(parse_data[:spi_split]).each do |program_code|
        skip = false
        parse_data[:skip_spi].each do |skip_expr|
          if program_code =~ skip_expr
            skip = true
            break
          end
        end

        next if skip
        rate_decimal = parse_rate(rate_text)
        raise "Invalid parse expression: #{spi}.  Each matched SPI expression should return exactly 2 non-blank match values." if rate_text.blank?

        # Run through any expressions designed to clean up the SPI program code text.
        if parse_data[:spi_cleanup]
          program_code = program_code
          parse_data[:spi_cleanup].each do |spi_cleanup|
            next unless spi_cleanup.length == 2
            program_code = program_code.gsub(spi_cleanup[0], spi_cleanup[1])
          end
        end

        programs << {program_code:program_code,amount:rate_decimal,text:rate_text}
      end
    end

    programs
  end

  def self.parse_rate r
    cleaned = r.gsub(/(\%|:|,)/,'').upcase.strip
    return 0 if cleaned=='FREE'
    return nil if !r.strip.match(/^[0-9]{0,3}\\.{0,1}[0-9]{0,3}$/)
    return BigDecimal(cleaned,3)*0.01
  end

  def self.parse_data_for country
    iso_code = country.european_union? ? 'EU' : country.iso_code
    case iso_code.upcase
    when "US"
      return {parser: /([^(]+)\s*\(([^)]+)\)/, spi_split: /,\s*/, exceptions: [/^\s*Free\s*$/, /^The duty rate provided for /, /^A duty upon the full value of the import/, /^No change/, /^cified in such announ/,/^Free, under the terms/], skip_spi: [], replaces:{'No change (A) Free'=>'Free','See U.S. note 3(e)'=>'See U.S. note 3e'}}
    when "CA"
      # Remove all spaces from the spi program codes, CA doesn't have any programs that should have spaces.
      return {parser: /([^:(]+):\s*\(([^)]+)\),*\s*/, spi_split: /,\s*/, exceptions: [], spi_cleanup: [[/\s/, ""]], skip_spi: [/^\s*General\s*$/i]}
    when "IT", "GB", "IE", "EU", "FR"
      return {parser: /((?:Free)|(?:\d+(?:\.\d+)?%))\s*:\s*\((.*?)\)/, spi_split: /,\s*/, spi_cleanup: [[/ERGA OMNES - Import/, "ERGA OMNES IMPORT"], [/ERGA OMNES - Veterin/, "ERGA OMNES VETERIN"], [/\s?-\s.*\z/, ""]], exceptions: [], skip_spi: []}
    else
      raise "No Special Program parser configured for #{iso_code}"
    end
  end
end; end; end
