require 'spec_helper'

describe OpenChain::CustomHandler::FootLocker::FootLockerHtsParser do
  def default_values
    {
      div: '3',
      style: '1386',
      internal_description: "FL SS POLO_PIQUE",
      customs_description: 'MENS 100% COTTON SHIRT',
      hts: '6105.10.0010',
      season: 'NA',
      weight: nil,
      spcss: nil,
      origin: nil,
      vendor: '19934',
      cat: '338',
      duty_rate: '0',
      duty_rate_kg: '0'
    }
  end

  def make_row(overrides={}, div='us')
    h = default_values.merge(overrides)
    h[:div] = div == 'us' ? '16' : '76'
    [:div, :style, :internal_description, :customs_description, :hts, :season, :spcss, :weight, :origin, :vendor, :cat,
     :duty_rate, :duty_rate_kg].collect {|k| h[k]}.to_csv(:quote_char=>"\007")
  end

  let!(:us) { Factory(:country, iso_code: 'US')}
  let!(:ca) { Factory(:country, iso_code: 'CA')}

  describe '#process_file' do
    before do
      @company = Factory(:company, alliance_customer_number: 'FOOLO')
      @cdefs = described_class.prep_custom_definitions [:prod_part_number, :prod_country_of_origin, :class_customs_description, :prod_season]
    end

    it 'does not snapshot a non-changed product' do
      h = default_values
      described_class.new.process_file(make_row, 'file_name')
      p = Product.first
      expect(p).to_not receive(:create_snapshot)
      described_class.new.process_file(make_row, 'file_name')
    end

    it 'creates a new product' do
      h = default_values
      expect_any_instance_of(Product).to receive(:create_snapshot)
      expect{described_class.new.process_file(make_row, 'file_name')}.to change(Product, :count).by(1)

      p = Product.first
      classification = p.classifications.find {|c| c.country_id == us.id }

      expect(p.importer_id).to eql(@company.id)
      expect(p.unique_identifier).to eql("FOOLO-#{h[:style]}")
      expect(p.name).to eql(h[:internal_description])
      expect(p.custom_value(@cdefs[:prod_part_number])).to eql(h[:style])
      expect(p.custom_value(@cdefs[:prod_country_of_origin])).to eql(h[:origin])
      expect(p.custom_value(@cdefs[:prod_season])).to eql(h[:season])
      expect(classification.custom_value(@cdefs[:class_customs_description])).to eql(h[:custom_description])
    end

    it 'does not set the country of origin if one does not exist' do
      h = default_values
      described_class.new.process_file(make_row({origin: nil}), 'file_name')
      p = Product.first
      expect(p.custom_value(@cdefs[:prod_country_of_origin])).to be_nil
    end

    it 'does not create an hts for country if an hts is not present' do
      h = default_values
      described_class.new.process_file(make_row({hts: nil}), 'file_name')
      p = Product.first
      expect(p.hts_for_country(us)).to be_empty
    end

    it 'handles both CA and US Divisions' do
      h = default_values
      rows = make_row({}, 'us') + make_row({hts: '1234.56.7890'}, 'ca')
      described_class.new.process_file(rows, 'file_name')
      p = Product.first
      expect(p.hts_for_country(us)).to be_present
      expect(p.hts_for_country(us)).to include('6105100010')
      expect(p.hts_for_country(ca)).to be_present
      expect(p.hts_for_country(ca)).to include('1234567890')

      expect(p.hts_for_country(us)).to_not include('1234567890')
      expect(p.hts_for_country(ca)).to_not include('6105100010')
    end

    it 'sets the hts for Canada if the Division is a Canadian Division' do
      h = default_values
      described_class.new.process_file(make_row({}, 'ca'), 'file_name')
      p = Product.first
      expect(p.hts_for_country(us)).to be_empty
      expect(p.hts_for_country(ca)).to include('6105100010')
    end

    it 'handles no hts number' do
      h = default_values
      no_hts_row = make_row({hts: nil}, 'file_name')

      expect{described_class.new.process_file(no_hts_row, 'file_name')}.to change(Product, :count).by(1)
    end
  end

  describe "#us" do
    it "returns the US country" do
      expect(described_class.new.us).to eql(us)
    end
  end

  describe "#clean_up_hts_number" do
    let(:hts_number) { '9004.10.0000' }

    it "removes all periods" do
      expect(described_class.new.clean_up_hts_number(hts_number)).to eql('9004100000')
    end
  end

  describe "#is_canada?" do
    it "should return true if the Division is a Canadian division" do
      expect(described_class.new.is_canada?('77')).to be_truthy
    end

    it "should return false if the Divison is not a Canadaian division" do
      expect(described_class.new.is_canada?('3')).to be_falsey
    end
  end

  describe ".integration folder" do
    it "uses integration folder" do
      expect(described_class.integration_folder).to eq ["www-vfitrack-net/footlocker_hts", "www-vfitrack-net/footlocker_hts"]
    end
  end
end