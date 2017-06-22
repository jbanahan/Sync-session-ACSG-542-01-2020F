require 'spec_helper'

describe OpenChain::CustomHandler::UnderArmour::UnderArmourMissingClassificationsUploadParser do
  describe 'can_view?' do
    let!(:subject) { described_class.new(nil) }
    let!(:ms) { stub_master_setup }
    let!(:user) { Factory(:master_user) }

    it "allow product-editing master users on systems with feature" do
      expect(ms).to receive(:custom_feature?).with('UA SAP').and_return true
      expect(user).to receive(:edit_products?).and_return true
      expect(subject.can_view? user).to eq true
    end

    it "blocks product-editing non-master users on systems with feature" do
      allow(ms).to receive(:custom_feature?).with('UA SAP').and_return true
      user = Factory(:user)
      allow(user).to receive(:edit_products?).and_return true
      expect(subject.can_view? user).to eq false
    end

    it "blocks product-editing master users on systems without feature" do
      expect(ms).to receive(:custom_feature?).with('UA SAP').and_return false
      expect(user).to receive(:edit_products?).and_return true
      expect(subject.can_view? user).to eq false
    end
    
    it "blocks non-product-editing master users on systems with feature" do
      allow(ms).to receive(:custom_feature?).with('UA SAP').and_return true
      expect(user).to receive(:edit_products?).and_return false
      expect(subject.can_view? user).to eq false
    end
  end

  describe 'process' do
    subject { described_class.new("custom file") }

    let(:header) { ["Article", "Name", "Destination Country Code", "Style", "Color", "Size", "Descriptive Size", "Site Code"] }
    let(:row_1) { ["art1", "shirt", "US", "stylish", "blue", "big", "descriptive size", "site1"] }
    let(:row_2) { ["art2", "shorts", "CA", "tacky", "red", "small", "descriptive size2", "site2"] }
  
    it "reads file, discards header, passes rows to #parse" do
      expect(subject).to receive(:foreach).with("custom file").and_return [header, row_1, row_2]
      expect(subject).to receive(:parse).with([row_1, row_2], [], {}, "file.csv")
      subject.process "user", "file.csv"
    end

    it "sends email if missing site codes are found" do
      stub_master_setup
      DataCrossReference.create!(key: "site1", value: "US", cross_reference_type: "ua_site")
      expect(subject).to receive(:foreach).with("custom file").and_return [header, row_1, row_2]
      subject.process "user", "file.csv"

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ["uacustomscompliance@underarmour.com"]
      expect(mail.subject).to eq "Missing Classifications Upload Error"
      expect(mail.body.raw_source).to include "The following site codes in file.csv were unrecognized: site2 (row 2)"
    end
  end

  describe 'parse' do
    subject { described_class.new("custom file") }

    let(:cdefs) { subject.cdefs }
    let(:row_1) { ["art num", "shirt", "US", "stylish", "blue", "big", "descriptive size", "site1"] }
    let(:row_2) { ["art num", "nice shirt", "CA", "stylish", "blue", "big", "descriptive size", "site2"] }
    
    it 'creates products' do      
      subject.parse [row_1], ["site1", "site2"], {}, "file.csv"
      expect(Product.count).to eq 1
      p = Product.first
      expect(p.unique_identifier).to eq "art num"
      expect(p.name).to eq "shirt"
      expect(p.custom_value(cdefs[:prod_import_countries])).to eq "US"
      expect(p.custom_value(cdefs[:prod_style])).to eq "stylish"
      expect(p.custom_value(cdefs[:prod_color])).to eq "blue"
      expect(p.custom_value(cdefs[:prod_size_code])).to eq "big"
      expect(p.custom_value(cdefs[:prod_size_description])).to eq "descriptive size"
      expect(p.custom_value(cdefs[:prod_site_codes])).to eq "site1"
    end

    it 'adds on to import countries, site codes of existing products; leave other fields unchanged' do
      subject.parse [row_1, row_2, row_2], ["site1", "site2"], {}, "file.csv" #check that duplicate data is ignored
      expect(Product.count).to eq 1
      p = Product.first
      expect(p.unique_identifier).to eq "art num"
      expect(p.name).to eq "shirt"
      expect(p.custom_value(cdefs[:prod_import_countries])).to eq "US\n CA"
      expect(p.custom_value(cdefs[:prod_style])).to eq "stylish"
      expect(p.custom_value(cdefs[:prod_color])).to eq "blue"
      expect(p.custom_value(cdefs[:prod_size_code])).to eq "big"
      expect(p.custom_value(cdefs[:prod_size_description])).to eq "descriptive size"
      expect(p.custom_value(cdefs[:prod_site_codes])).to eq "site1\n site2"
    end
  
    it 'skips row and records missing site codes' do
      row_1[7] = "site3"
      missing_codes = {}
      subject.parse [row_1, row_2], ["site1","site2"], missing_codes, "file.csv"
      
      expect(Product.count).to eq 1
      p = Product.first
      expect(p.custom_value(cdefs[:prod_site_codes])).to eq "site2"
      expect(missing_codes).to eq({1 => "site3"})
    end
  end
end