module OpenChain; module OfficialTariffProcessor; class EuProcessor
  def self.process official_tariff
    cid = official_tariff.country_id
    srk = official_tariff.special_rate_key
    # do nothing if the rates are already built for this key
    return unless SpiRate.where(special_rate_key:srk,country_id:cid).empty?

    rh = rate_hash(official_tariff)
    rh.each do |rate_data|
      SpiRate.create!(special_rate_key:srk,
        country_id:cid,program_code:rate_data[:program_code],
        rate:rate_data[:amount],rate_text:rate_data[:text])
    end
  end

  def self.rate_hash official_tariff
    # 	3.2%: (SPGL - TarrPref Excl), 9999.99%: (KP - North Korea - I), Free: (AL,DZ,AD- CstUnDty,XC,CL,EPA,EG,TOUT- NonPrfTQ,EEA,SWITZ,FO,MK,IL,JO,LB,XL,MX,ME,MA,PS,S M- CstUnDty,ZA,CH,SY,TN,TR- CstUnDty,BA - Tariff preferen,XK - Tariff preferen,XS - Tariff preferen,EU,ERGA OMNES - Airwort,PG - Tariff preferen,CARI - TarrPref Excl,ESA - Tariff Prefere,KR - Preferential ta,KR - Tariff Preferen,MD - Tariff Preferen,PE - Tariff Preferen,CO - Tariff Preferen,CAMER - Tariff Prefe,SPGA - Tariff prefer,UA - Tariff preferen,FJ - Fiji,CM - Tariff preferen,GE - Tariff preferen,EC - Tariff preferen,SPGE - PrefTariff,LOMB - TARIFF PREFER)
    text = official_tariff.special_rates
    return {} if text.blank?
    text = clean_text(text)
    r = []
    text.split(')').each do |rate_text|
      next if rate_text.blank?
      pair = rate_text.split('(')
      amount = parse_rate(pair[0])
      next if pair[1].blank?
      programs = pair[1].strip.gsub(/\)/,'').split(',').collect{|s| s.strip}
      programs.each do |p|
        next if p.blank?
        cp = clean_program(p)
        #only saving Peru & Columbia for now, later sub in other programs we're tracking
        if ['PE','CO'].include?(cp)
          r << {program_code:cp,amount:amount,text:pair[0].gsub(/(:|,)/,'').strip}
        end
      end
    end
    return r
  end

  def self.parse_rate r
    cleaned = r.gsub(/(\%|:|,)/,'').upcase.strip
    return 0 if cleaned=='FREE'
    return nil if !r.strip.match(/^[0-9]{0,3}\\.{0,1}[0-9]{0,3}$/)
    return BigDecimal(cleaned,3)*0.01
  end

  def self.clean_program program_text
    program_text.upcase.split('-').first.strip
  end

  def self.clean_text text
    # handle special cases
    text = text.gsub("[see U.S. note 3 of this subchapter)","[see U.S. note 3 of this subchapter]")
    text
  end
end; end; end
