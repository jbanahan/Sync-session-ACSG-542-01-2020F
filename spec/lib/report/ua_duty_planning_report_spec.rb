describe OpenChain::Report::UaDutyPlanningReport do
  describe '#run_report' do
    before :each do
      allow(described_class).to receive(:permission?).and_return true
      @cdefs = described_class.prep_custom_definitions([:prod_export_countries,:prod_import_countries,:prod_seasons,:expected_duty_rate])


      @country_rates = {'CN'=>BigDecimal('0.32'),'US'=>BigDecimal('.1112'),'MX'=>BigDecimal('0.42')}

    end
    let :user do
      Factory(:master_user)
    end
    let :make_countries do
      r = {}
      @country_rates.keys.each do |iso|
        r[iso] = Factory(:country,:iso_code=>iso,import_location:true)
      end
      r
    end
    let :make_tariffs do
      @country_rates.collect do |iso,rate|
        country = Country.find_by iso_code: iso
        country.official_tariffs.create!(hts_code:'1234567890',common_rate_decimal:rate,special_rates:'XYZ')
      end
    end
    let :make_product do
      p = Factory(:product,name:'pname')
      # intentionally using CN for both import & export country
      # to be sure we don't generate record w/ same country in both positions
      p.update_custom_value!(@cdefs[:prod_export_countries],"CN\nMX")
      p.update_custom_value!(@cdefs[:prod_import_countries],"US\nCN")
      p.update_custom_value!(@cdefs[:prod_seasons],['SS16','FW17','SS18'].join("\n"))

      @country_rates.keys.each do |iso|
        country = Country.find_by iso_code: iso
        Factory(:tariff_record,hts_1:'1234567890',classification:Factory(:classification,country:country,product:p))
      end
      p
    end

    it 'should generate csv by season' do
      make_countries
      make_tariffs
      p = make_product
      f = described_class.run_report user, season: 'FW17'
      results = CSV.read(f.path)
      expect(results.length).to eq 4 #three results + headings
      headings = results[0]
      expect(headings).to eq ['Country of Origin','Region of Destination','Style','','HTS Code','','Duty']
      expect(results[1]).to eq ['CN','US',p.unique_identifier,p.name,'1234.56.7890','1234.56.7890','11.12']
      expect(results[2]).to eq ['MX','CN',p.unique_identifier,p.name,'1234.56.7890','1234.56.7890','32.0']
      expect(results[3]).to eq ['MX','US',p.unique_identifier,p.name,'1234.56.7890','1234.56.7890','11.12']
    end
    it 'should generate csv by style list in s3' do
      @country_rates = {'CN'=>BigDecimal('0.21')}
      make_countries
      make_tariffs
      p = make_product
      expect(OpenChain::S3).to receive(:bucket_name).and_return 'mybucket'
      expect(OpenChain::S3).to receive(:get_data).with('mybucket','mypath').and_return("ABC\n#{p.unique_identifier}\nDEF\n")
      opts = {style_s3_path:'mypath'}
      expect(described_class.find_products(user,opts,{}).to_a).to eq [p]
    end
    it 'should fail if user does not have permission' do
      allow(described_class).to receive(:permission?).and_return false
      expect{described_class.run_report user, season:'FW17'}.to raise_error(/permission/)
    end

    context 'override scenarios' do
      it 'should use expected duty rate from classification' do
        @country_rates = {'CN'=>BigDecimal('0.21'),'MX'=>BigDecimal('0.03')}
        countries = make_countries
        Factory(:trade_lane,origin_country:countries['MX'],destination_country:countries['CN'],tariff_adjustment_percentage:'1')
        make_tariffs
        p = make_product
        p.classifications.where(country_id:countries['CN'].id).first.update_custom_value!(@cdefs[:expected_duty_rate],5.8)
        f = described_class.run_report user, season: 'FW17'
        results = CSV.read(f.path)
        expect(results.length).to eq 2
        expect(results[1]).to eq ['MX','CN',p.unique_identifier,p.name,'1234.56.7890','1234.56.7890','5.8']
      end
      it 'should use default common decimal rate with late uplift' do
        @country_rates = {'CN'=>BigDecimal('0.21'),'MX'=>BigDecimal('0.03')}
        countries = make_countries
        Factory(:trade_lane,origin_country:countries['MX'],destination_country:countries['CN'],tariff_adjustment_percentage:'1')
        make_tariffs
        p = make_product
        f = described_class.run_report user, season: 'FW17'
        results = CSV.read(f.path)
        expect(results.length).to eq 2
        expect(results[1]).to eq ['MX','CN',p.unique_identifier,p.name,'1234.56.7890','1234.56.7890','22.0']
      end
      it 'should use tpp decimal rate' do
        @country_rates = {'CN'=>BigDecimal('0.21'),'MX'=>BigDecimal('0.03')}
        countries = make_countries
        Factory(:trade_lane,origin_country:countries['MX'],destination_country:countries['CN'],tariff_adjustment_percentage:'1')
        Factory(:trade_preference_program,origin_country:countries['MX'],destination_country:countries['CN'],tariff_identifier:'CNMX')
        make_tariffs
        Factory(:spi_rate,country:countries['CN'],special_rate_key:OfficialTariff.first.special_rate_key,program_code:'CNMX',rate:BigDecimal('0.02'))
        p = make_product
        f = described_class.run_report user, season: 'FW17'
        results = CSV.read(f.path)
        expect(results.length).to eq 2
        expect(results[1]).to eq ['MX','CN',p.unique_identifier,p.name,'1234.56.7890','1234.56.7890','2.0']
      end
      it 'should use tpp decimal rate with lane uplift' do
        @country_rates = {'CN'=>BigDecimal('0.21'),'MX'=>BigDecimal('0.03')}
        countries = make_countries
        Factory(:trade_lane,origin_country:countries['MX'],destination_country:countries['CN'],tariff_adjustment_percentage:'1')
        Factory(:trade_preference_program,origin_country:countries['MX'],destination_country:countries['CN'],tariff_identifier:'CNMX',tariff_adjustment_percentage:'2.1')
        make_tariffs
        Factory(:spi_rate,country:countries['CN'],special_rate_key:OfficialTariff.first.special_rate_key,program_code:'CNMX',rate:BigDecimal('0.02'))
        p = make_product
        f = described_class.run_report user, season: 'FW17'
        results = CSV.read(f.path)
        expect(results.length).to eq 2
        expect(results[1]).to eq ['MX','CN',p.unique_identifier,p.name,'1234.56.7890','1234.56.7890','4.1']
      end
      it 'should use tpp decimal rate with override' do
        @country_rates = {'CN'=>BigDecimal('0.21'),'MX'=>BigDecimal('0.03')}
        countries = make_countries
        Factory(:trade_lane,origin_country:countries['MX'],destination_country:countries['CN'],tariff_adjustment_percentage:'1')
        tpp = Factory(:trade_preference_program,origin_country:countries['MX'],destination_country:countries['CN'],tariff_identifier:'CNMX',tariff_adjustment_percentage:'2.1')
        Factory(:tpp_hts_override,trade_preference_program:tpp,hts_code:'123',rate:'6.2')
        make_tariffs
        Factory(:spi_rate,country:countries['CN'],special_rate_key:OfficialTariff.first.special_rate_key,program_code:'CNMX',rate:BigDecimal('0.02'))
        p = make_product
        f = described_class.run_report user, season: 'FW17'
        results = CSV.read(f.path)
        expect(results.length).to eq 2
        expect(results[1]).to eq ['MX','CN',p.unique_identifier,p.name,'1234.56.7890','1234.56.7890','6.2']
      end
      it 'should use most specific override' do
        @country_rates = {'CN'=>BigDecimal('0.21'),'MX'=>BigDecimal('0.03')}
        countries = make_countries
        Factory(:trade_lane,origin_country:countries['MX'],destination_country:countries['CN'],tariff_adjustment_percentage:'1')
        tpp = Factory(:trade_preference_program,origin_country:countries['MX'],destination_country:countries['CN'],tariff_identifier:'CNMX',tariff_adjustment_percentage:'2.1')
        Factory(:tpp_hts_override,trade_preference_program:tpp,hts_code:'123',rate:'6.2')
        Factory(:tpp_hts_override,trade_preference_program:tpp,hts_code:'1234',rate:'8')
        make_tariffs
        Factory(:spi_rate,country:countries['CN'],special_rate_key:OfficialTariff.first.special_rate_key,program_code:'CNMX',rate:BigDecimal('0.02'))
        p = make_product
        f = described_class.run_report user, season: 'FW17'
        results = CSV.read(f.path)
        expect(results.length).to eq 2
        expect(results[1]).to eq ['MX','CN',p.unique_identifier,p.name,'1234.56.7890','1234.56.7890','8.0']
      end
      it 'should return blank with no common decimal rate or lane' do
        @country_rates = {'CN'=>nil,'MX'=>BigDecimal('0.03')}
        make_countries
        make_tariffs
        p = make_product
        f = described_class.run_report user, season: 'FW17'
        results = CSV.read(f.path)
        expect(results[1]).to eq ['MX','CN',p.unique_identifier,p.name,'1234.56.7890','1234.56.7890','']
      end
      it 'should return blank with no common decimal rate, with lane, w/o tpp' do
        @country_rates = {'CN'=>nil,'MX'=>BigDecimal('0.03')}
        countries = make_countries
        Factory(:trade_lane,origin_country:countries['MX'],destination_country:countries['CN'],tariff_adjustment_percentage:'1')
        make_tariffs
        p = make_product
        f = described_class.run_report user, season: 'FW17'
        results = CSV.read(f.path)
        expect(results[1]).to eq ['MX','CN',p.unique_identifier,p.name,'1234.56.7890','1234.56.7890','']
      end
    end
    context 'special cases' do
      it 'should only use first tariff record for sets' do
        @country_rates = {'CN'=>BigDecimal('0.21'),'MX'=>BigDecimal('0.03')}
        countries = make_countries
        Factory(:trade_lane,origin_country:countries['MX'],destination_country:countries['CN'],tariff_adjustment_percentage:'1')
        make_tariffs
        Factory(:official_tariff,hts_code:'987654321',common_rate_decimal:0.99,country_id:countries['CN'].id)
        p = make_product
        p.classifications.find_by(country: countries['CN']).tariff_records(line_number:'99',hts_1:'987654321')
        f = described_class.run_report user, season: 'FW17'
        results = CSV.read(f.path)
        expect(results.length).to eq 2
        expect(results[1]).to eq ['MX','CN',p.unique_identifier,p.name,'1234.56.7890','1234.56.7890','22.0']
      end
    end
  end

  describe '#permission?' do

    let! (:master_setup) {
      ms = stub_master_setup
      allow(ms).to receive(:custom_feature?).with("UA-TPP").and_return true
      ms
    }

    before :each do
      c = Company.new(master:true)
      @u = User.new
      @u.company = c
      allow(@u).to receive(:view_products?).and_return true
    end
    it 'should be available if user can view products and is in master company and UA-TPP is enabled' do
      expect(described_class.permission?(@u)).to be_truthy
    end
    context 'not available' do
      after :each do
        expect(described_class.permission?(@u)).to be_falsey
      end
      it 'if user cannot view products' do
        allow(@u).to receive(:view_products?).and_return false
      end
      it 'if user is not master' do
        @u.company.master = false
      end
      it 'if UA-TPP not enabled' do
        expect(master_setup).to receive(:custom_feature?).with("UA-TPP").and_return false
      end
    end
  end
end
