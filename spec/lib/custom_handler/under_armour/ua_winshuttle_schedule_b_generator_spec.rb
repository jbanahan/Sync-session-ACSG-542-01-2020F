require 'spec_helper'

describe OpenChain::CustomHandler::UnderArmour::UaWinshuttleScheduleBGenerator do
  it "should have sync_code" do
    described_class.new.sync_code.should == 'winshuttle-b'
  end
  describe :run_and_email do
    it "should run_and_email" do
      d = double('class')
      d.should_receive(:sync_xls).and_return 'xyz'
      d.should_receive(:email_file).with('xyz','j@sample.com')
      ArchivedFile.should_receive(:make_from_file!).with('xyz','Winshuttle Schedule B Output',/Sent to j@sample.com at /)
      described_class.stub(:new).and_return d
      described_class.run_and_email('j@sample.com')
    end
    it "should not email if file is nil" do
      d = double('class')
      d.should_receive(:sync_xls).and_return nil
      d.should_not_receive(:email_file)
      ArchivedFile.should_not_receive(:make_from_file!)
      described_class.stub(:new).and_return d
      described_class.run_and_email('j@sample.com')
    end
  end
  describe :sync do
    def create_product
      tr = Factory(:tariff_record,schedule_b_1:'1234567890',classification:Factory(:classification,country_id:@us.id))
      tr.product.update_custom_value! @colors_cd, "001"
      tr.product
    end
    def collect_rows
      rows = []
      described_class.new.sync {|row| rows << row}
      rows
    end
    before :each do
      @us = Factory(:country,iso_code:'US')
      @colors_cd = described_class.prep_custom_definitions([:colors])[:colors]
    end
    it "should only return US schedule B" do
      p = create_product
      p.update_custom_value! @colors_cd, "001\n002"
      r = collect_rows
      expect(r.length).to eq 3
      row = r[1]
      expect(row.length).to eq 5
      expect(row[0]).to eq ''
      expect(row[1]).to eq "#{p.unique_identifier}-001"
      expect(row[2]).to eq '0050'
      expect(row[3]).to eq 'CA'
      expect(row[4]).to eq p.classifications.first.tariff_records.first.schedule_b_1.hts_format
      row = r[2]
      expect(row[0]).to eq ''
      expect(row[1]).to eq "#{p.unique_identifier}-002"
      expect(row[2]).to eq '0050'
      expect(row[3]).to eq 'CA'
      expect(row[4]).to eq p.classifications.first.tariff_records.first.schedule_b_1.hts_format
    end
    it "should eliminate items that don't need sync via query" do
      create_product
      expect(collect_rows.length).to eq 2
      expect(collect_rows).to be_empty #second run should not return values since they're synchronized
    end
    it "should write headers" do
      create_product
      r = collect_rows.first
      expect(r[0]).to match /Log Winshuttle RUNNER for TRANSACTION 10.5\nZM30-Add-Code.TxR\n.*\nMode:  Batch\nPRD-100, pmckeldin/
      expect(r[1]).to eq "ZMMHSCONV-MATNR(01)\nMaterial number, without search help"
      expect(r[2]).to eq "ZMMHSCONV-WERKS(01)\nPlant"
      expect(r[3]).to eq "ZMMHSCONV-LAND2(01)\nCountry Key"
      expect(r[4]).to eq "ZMMHSCONV-STAWN2(01)\nCommodity code / Import code number for foreign trade"
    end
  end
  describe :email_file do
    before :each do 
      @f = double('file')
      @mailer = double(:mailer)
      @mailer.should_receive(:deliver)
    end
    it "should email result" do
      OpenMailer.should_receive(:send_simple_html).with('joe@sample.com','Winshuttle Schedule B Output File','Your Winshuttle schedule b output file is attached.  For assistance, please email support@vandegriftinc.com',[@f]).and_return(@mailer)
      described_class.new.email_file @f, 'joe@sample.com'
    end
    it "should make original_filename method on file object" do
      OpenMailer.stub(:send_simple_html).and_return(@mailer)
      described_class.new.email_file @f, 'joe@sample.com'
      @f.original_filename.should match /winshuttle_schedule_b_[[:digit:]]{8}\.xls/
    end
  end
end
