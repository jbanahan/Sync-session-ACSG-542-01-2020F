require 'spec_helper'

describe OpenChain::CustomHandler::UnderArmour::UnderArmourMissingClassificationsUploadParser do
  let!(:user) { Factory(:master_user) }
  let!(:custom_file) { double "custom file "}
  before { allow(custom_file).to receive(:attached_file_name).and_return "file.csv" }

  describe 'can_view?' do
    let!(:subject) { described_class.new(nil) }
    let!(:ms) { stub_master_setup }

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

    let(:header) { ["Article", "Name", "Destination Country Code", "Style", "Color", "Size", "Descriptive Size", "Site Code"] }
    let(:row_1) { ["art1", "shirt", "US", "stylish", "blue", "big", "descriptive size", "site1"] }
    let(:row_2) { ["art2", "shorts", "CA", "tacky", "red", "small", "descriptive size2", "site2"] }
    
    subject { described_class.new(custom_file) }
  
    it "reads file, discards header, passes rows to #parse" do
      expect(subject).to receive(:foreach).with(custom_file).and_return [header, row_1, row_2]
      expect(subject).to receive(:parse).with([row_1, row_2], [], {}, 'file.csv')
      subject.process user
      m = user.messages.first
      expect(m.subject).to eq "File Processing Complete"
      expect(m.body).to eq "Missing Classifications Upload processing for file file.csv is complete."
    end

    it "sends email if missing site codes are found" do
      stub_master_setup
      DataCrossReference.create!(key: "site1", value: "US", cross_reference_type: "ua_site")
      expect(subject).to receive(:foreach).with(custom_file).and_return [header, row_1, row_2]
      subject.process user

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq [described_class::ERROR_EMAIL]
      expect(mail.subject).to eq "Missing Classifications Upload Error"
      expect(mail.body.raw_source).to include "The following site codes in file.csv were unrecognized: site2 (row 2)"
      expect(Product.count).to eq 1
    end

    it "doesn't send email if site code is blank" do
      row_1[7] = row_2[7] = ""
      expect(subject).to receive(:foreach).with(custom_file).and_return [header, row_1, row_2]
      subject.process user

      mail = ActionMailer::Base.deliveries.pop
      expect(mail).to be_nil
      expect(Product.count).to eq 2
    end
  
    it "Notifies user if upload fails" do
      expect(subject).to receive(:process_file).with(custom_file, user).and_raise "KABOOM!"
      subject.process user
      m = user.messages.first
      expect(m.subject).to eq "File Processing Complete With Errors"
      expect(m.body).to eq "Unable to process file file.csv due to the following error:<br>KABOOM!"
    end
  end

  describe 'parse' do
    subject { described_class.new(custom_file) }

    let(:cdefs) { subject.cdefs }
    let(:row_1) { ["art num", "shirt", "US", "stylish", "blue", "big", "descriptive size", "site1"] }
    let(:row_2) { ["art num", "nice shirt", "CA", "meh", "green", "medium", "descriptive size2", "site2"] }
    let(:row_3) { ["art num2", "ugly shirt", "CN", "frumpy", "mauve", "too small", "descriptive size3", "site3"] }
    
    it 'creates products; aggregates import countries, site codes for a single article, uses the last row for other fields' do      
      subject.parse [row_1, row_2, row_3], ["site1", "site2", "site3"], {}, custom_file
      expect(Product.count).to eq 2
      p = Product.first
      expect(p.entity_snapshots.count).to eq 1
      expect(p.unique_identifier).to eq "art num"
      expect(p.name).to eq "nice shirt"
      expect(p.custom_value(cdefs[:prod_import_countries])).to eq "CA\n US"
      expect(p.custom_value(cdefs[:prod_style])).to eq "meh"
      expect(p.custom_value(cdefs[:prod_color])).to eq "green"
      expect(p.custom_value(cdefs[:prod_size_code])).to eq "medium"
      expect(p.custom_value(cdefs[:prod_size_description])).to eq "descriptive size2"
      expect(p.custom_value(cdefs[:prod_site_codes])).to eq "site1\n site2"

      p2 = Product.last
      expect(p2.entity_snapshots.count).to eq 1
      expect(p2.unique_identifier).to eq "art num2"
      expect(p2.name).to eq "ugly shirt"
      expect(p2.custom_value(cdefs[:prod_import_countries])).to eq "CN"
      expect(p2.custom_value(cdefs[:prod_style])).to eq "frumpy"
      expect(p2.custom_value(cdefs[:prod_color])).to eq "mauve"
      expect(p2.custom_value(cdefs[:prod_size_code])).to eq "too small"
      expect(p2.custom_value(cdefs[:prod_size_description])).to eq "descriptive size3"
      expect(p2.custom_value(cdefs[:prod_site_codes])).to eq "site3"
    end

    it 'updates products; aggregates import countries, site codes of existing products; leaves other fields unchanged' do
      subject.parse [row_1], ["site1", "site2"], {}, custom_file
      subject.parse [row_2, row_2], ["site1", "site2"], {}, custom_file #check that duplicate data is ignored
      expect(Product.count).to eq 1
      p = Product.first
      expect(p.entity_snapshots.count).to eq 2
      expect(p.unique_identifier).to eq "art num"
      expect(p.name).to eq "shirt"
      expect(p.custom_value(cdefs[:prod_import_countries])).to eq "CA\n US"
      expect(p.custom_value(cdefs[:prod_style])).to eq "stylish"
      expect(p.custom_value(cdefs[:prod_color])).to eq "blue"
      expect(p.custom_value(cdefs[:prod_size_code])).to eq "big"
      expect(p.custom_value(cdefs[:prod_size_description])).to eq "descriptive size"
      expect(p.custom_value(cdefs[:prod_site_codes])).to eq "site1\n site2"
    end
  
    it 'skips row and records missing site codes' do
      row_1[7] = "site3"
      missing_codes = {}
      expect_any_instance_of(Product).to receive(:create_snapshot).with(User.integration, nil, "UA Missing Classification Upload Parser")
      subject.parse [row_1, row_2], ["site1","site2"], missing_codes, custom_file
      
      expect(Product.count).to eq 1
      p = Product.first
      expect(p.custom_value(cdefs[:prod_site_codes])).to eq "site2"
      expect(missing_codes).to eq({1 => "site3"})
    end

    it "doesn't snapshot unchanged products" do
      expect_any_instance_of(Product).to receive(:create_snapshot).with(User.integration, nil, "UA Missing Classification Upload Parser").once
      subject.parse [row_1], ["site1", "site2"], {}, custom_file
      subject.parse [row_1], ["site1", "site2"], {}, custom_file
    end
  end
end