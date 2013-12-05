require 'spec_helper'

describe OpenChain::CustomHandler::UnderArmour::UaWinshuttleProductGenerator do

  it "should have sync_code" do
    described_class.new.sync_code.should == 'winshuttle'
  end
  describe :run_and_email do
    it "should run_and_email" do
      d = double('class')
      d.should_receive(:sync_xls).and_return 'xyz'
      d.should_receive(:email_file).with('xyz','j@sample.com')
      ArchivedFile.should_receive(:make_from_file!).with('xyz','Winshuttle Output',/Sent to j@sample.com at /)
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
    before :each do
      @plant_cd = described_class.prep_custom_definitions([:plant_codes])[:plant_codes]
      @colors_cd = described_class.prep_custom_definitions([:colors])[:colors]
      DataCrossReference.load_cross_references StringIO.new("0010,US\n0011,CA\n0012,CN"), DataCrossReference::UA_PLANT_TO_ISO
      @ca = Factory(:country,iso_code:'CA')
      @us = Factory(:country,iso_code:'US')
      @cn = Factory(:country,iso_code:'CN')
      @mx = Factory(:country,iso_code:'MX')
    end
    it "should elminiate items that don't need sync via query" do
      #prepping data
      p = Factory(:product)
      p.update_custom_value! @plant_cd, "0010\n0011"
      p.update_custom_value! @colors_cd, '001'
      DataCrossReference.stub(:find_ua_material_color_plant).and_return('1')
      Factory(:tariff_record,hts_1:"12345678",classification:Factory(:classification,country_id:@us.id,product:p))
      rows = []
      described_class.new.sync {|row| rows << row}
      rows.size.should == 2

      #running a second time shouldn't result in any rows from query to be processed
      rows = []
      g = described_class.new
      g.should_not_receive(:preprocess_row)
      g.sync {|r| rows << r}
      rows.should be_empty
    end
    it "should match plant to country" do
      p = Factory(:product)
      p.update_custom_value! @plant_cd, "0010\n0011"
      p.update_custom_value! @colors_cd, '001'
      DataCrossReference.stub(:find_ua_material_color_plant).and_return('1')
      [@ca,@us,@cn,@mx].each do |c|
        #create a classification with tariff for all countries
        Factory(:tariff_record,hts_1:"#{c.id}12345678",classification:Factory(:classification,country_id:c.id,product:p))
      end
      rows = []
      described_class.new.sync {|row| rows << row}
      rows.size.should == 3
      [rows[1],rows[2]].each do |r|
        r[0].should be_blank
        r[1].should == "#{p.unique_identifier}-001"
        ['0010','0011'].include?(r[2]).should be_true
        r[3].should == "#{r[2]=='0010' ? @us.id: @ca.id}12345678".hts_format
      end
    end
    it "should write color codes that are in the xref" do
      p = Factory(:product)
      p.update_custom_value! @plant_cd, "0010\n0011"
      p.update_custom_value! @colors_cd, "001\n002"
      DataCrossReference.create_ua_material_color_plant! p.unique_identifier, '001', '0010'
      DataCrossReference.create_ua_material_color_plant! p.unique_identifier, '002', '0011'
      [@ca,@us].each do |c|
        #create a classification with tariff for relevant countries
        Factory(:tariff_record,hts_1:"#{c.id}12345678",classification:Factory(:classification,country_id:c.id,product:p))
      end
      rows = []
      described_class.new.sync {|row| rows << row}
      rows.size.should == 3
      [rows[1],rows[2]].each do |r|
        r.should have(4).elements
        r[0].should be_blank
        r[1].should == "#{p.unique_identifier}-#{r[2]=='0010' ? '001' : '002'}"
        ['0010','0011'].include?(r[2]).should be_true
        r[3].should == "#{r[2]=='0010' ? @us.id: @ca.id}12345678".hts_format
      end
    end
    it "should write headers" do
      p = Factory(:product)
      p.update_custom_value! @plant_cd, "0010"
      p.update_custom_value! @colors_cd, '001'
      DataCrossReference.stub(:find_ua_material_color_plant).and_return('1')
      Factory(:tariff_record,hts_1:"12345678",classification:Factory(:classification,country_id:@us.id,product:p))
      rows = []
      described_class.new.sync {|row| rows << row}
      r = rows.first
      r[0].should match /Log Winshuttle RUNNER for TRANSACTION 10\.2\nMM02-Change HTS Code\.TxR\n.*\nMode:  Batch\nPRD-100, pmckeldin/
      r[1].should == 'Material Number'
      r[2].should == 'Plant'
      r[3].should == 'HTS Code'
    end
    it "should only send changed tariff codes since the last send" do
      p = Factory(:product)
      p.update_custom_value! @plant_cd, "0010\n0011"
      p.update_custom_value! @colors_cd, '001'
      DataCrossReference.stub(:find_ua_material_color_plant).and_return('1')
      [@ca,@us].each do |c|
        #create a classification with tariff for all countries
        Factory(:tariff_record,hts_1:"#{c.id}12345678",classification:Factory(:classification,country_id:c.id,product:p))
      end
      rows = []
      described_class.new.sync {|row| rows << row}
      rows.size.should == 3
      p.update_attributes(updated_at:2.minutes.from_now)
      p.reload
      p.classifications.find_by_country_id(@ca.id).tariff_records.first.update_attributes(hts_1:'987654321')
      rows = []
      described_class.new.sync {|row| rows << row}
      rows.size.should == 2
      r = rows.last
      r[0].should be_blank
      r[1].should == "#{p.unique_identifier}-001"
      r[2].should == '0011'
      r[3].should == '987654321'.hts_format
    end
  end

  describe :email_file do
    before :each do 
      @f = double('file')
      @mailer = double(:mailer)
      @mailer.should_receive(:deliver)
    end
    it "should email result" do
      OpenMailer.should_receive(:send_simple_html).with('joe@sample.com','Winshuttle Product Output File','Your Winshuttle product output file is attached.  For assistance, please email support@vandegriftinc.com',[@f]).and_return(@mailer)
      described_class.new.email_file @f, 'joe@sample.com'
    end
    it 'should make original_filename method on file object' do
      OpenMailer.stub(:send_simple_html).and_return(@mailer)
      described_class.new.email_file @f, 'joe@sample.com'
      @f.original_filename.should match /winshuttle_[[:digit:]]{8}\.xls/
    end
  end
end
