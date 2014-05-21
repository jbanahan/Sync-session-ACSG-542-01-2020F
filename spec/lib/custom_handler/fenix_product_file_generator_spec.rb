require 'spec_helper'

describe OpenChain::CustomHandler::FenixProductFileGenerator do
  
  before :each do
    @canada = Factory(:country,:iso_code=>'CA')
    @code = 'XYZ'
    @h = OpenChain::CustomHandler::FenixProductFileGenerator.new(@code)
  end
  describe "generate" do
    it "should find products, make file, and ftp" do
      @h.should_receive(:find_products).and_return('y')
      @h.should_receive(:make_file).with('y').and_return('z')
      @h.should_receive(:ftp_file).with('z').and_return('a')
      @h.generate.should == 'a'
    end
  end

  describe "find_products" do
    before :each do
      @to_find_1 = Factory(:tariff_record,:hts_1=>'1234567890',:classification=>Factory(:classification,:country_id=>@canada.id)).product
      @to_find_2 = Factory(:tariff_record,:hts_1=>'1234567891',:classification=>Factory(:classification,:country_id=>@canada.id)).product
    end
    it "should find products that need sync and have canadian classifications" do
      @h.find_products.to_a.should == [@to_find_1,@to_find_2] 
    end
    it "should filter on importer_id if given" do
      @to_find_1.update_attributes(:importer_id => 100)
      h = @h.class.new(@code, 100)
      h.find_products.to_a.should == [@to_find_1]
    end
    it "should apply additional_where filters" do
      @to_find_1.update_attributes(:name=>'XYZ')
      h = @h.class.new(@code, nil, nil, "products.name = 'XYZ'")
      h.find_products.to_a.should == [@to_find_1]
    end
    it "should not find products that don't have canada classifications but need sync" do
      different_country_product = Factory(:tariff_record,:hts_1=>'1234567891',:classification=>Factory(:classification)).product
      @h.find_products.to_a.should == [@to_find_1,@to_find_2] 
    end
    it "should not find products that have classification but don't need sync" do
      @to_find_2.update_attributes(:updated_at=>1.hour.ago)
      @to_find_2.sync_records.create!(:trading_partner=>"fenix-#{@code}",:sent_at=>1.minute.ago,:confirmed_at=>1.minute.ago)
      @h.find_products.to_a.should == [@to_find_1] 
    end
  end

  describe "make_file" do
    before :each do
      @p = Factory(:product,:unique_identifier=>'myuid')
      c = @p.classifications.create!(:country_id=>@canada.id)
      t = c.tariff_records.create!(:hts_1=>'1234567890')
    end
    after :each do 
      @t.unlink if @t
    end
    it "should generate output file with given products" do
      @t = @h.make_file [@p] 
      IO.read(@t.path).should == "#{"N".ljust(15)}#{@code.ljust(9)}#{"".ljust(7)}#{"myuid".ljust(40)}1234567890\r\n"
    end
    it "should generate output file using part number" do
      pn_def = CustomDefinition.create! label: "Part Number", module_type: "Product", data_type: "string"
      @p.update_custom_value! pn_def, "ABC123"
      @h = OpenChain::CustomHandler::FenixProductFileGenerator.new(@code, nil, true)
      @t = @h.make_file [@p] 
      IO.read(@t.path).should == "#{"N".ljust(15)}#{@code.ljust(9)}#{"".ljust(7)}#{"ABC123".ljust(40)}1234567890\r\n"
    end
    it "should write sync records with dummy confirmation date" do
      @t = @h.make_file [@p] 
      @p.reload
      @p.should have(1).sync_records
      sr = @p.sync_records.find_by_trading_partner("fenix-#{@code}")
      sr.sent_at.should < sr.confirmed_at
      sr.confirmation_file_name.should == "Fenix Confirmation"
    end
    it "should use CRLF line breaks" do
      p2 = Factory(:product,:unique_identifier=>'myuid2')
      c = p2.classifications.create!(:country_id=>@canada.id)
      t = c.tariff_records.create!(:hts_1=>'1234567890')
      @t = @h.make_file [@p,p2]
      x = IO.read @t.path
      x.index("\r\n").should == 81
    end
  end

  describe "ftp file" do
    it "should send ftp file to ftp2 server and delete it" do
      t = mock("tempfile")
      t.should_receive(:path).and_return('/tmp/a.txt')
      t.should_receive(:unlink)
      FtpSender.should_receive(:send_file,).with('ftp2.vandegriftinc.com','VFITRack','RL2VFftp',t,{:folder=>'to_ecs/fenix_products',:remote_file_name=>'a.txt'})
      @h.ftp_file t
    end
  end

  describe "run_schedulable" do
    it "should pass in all possible options when provided" do
      hash = {"fenix_customer_code" => "XYZ", "importer_id" => "23",
          "use_part_number" => "false", "additional_where" => "5 > 3"}
      fpfg = OpenChain::CustomHandler::FenixProductFileGenerator.new("XYZ","23",false,"5 > 3")

      OpenChain::CustomHandler::FenixProductFileGenerator.should_receive(:new).with("XYZ","23",false,"5 > 3").and_return(fpfg)
      OpenChain::CustomHandler::FenixProductFileGenerator.any_instance.should_receive(:generate)
      OpenChain::CustomHandler::FenixProductFileGenerator.run_schedulable(hash)
    end

    it "should convert strings of true into keywords of true" do
      hash = {"fenix_customer_code" => "XYZ", "importer_id" => "23",
          "use_part_number" => "true", "additional_where" => "5 > 3"}
      fpfg = OpenChain::CustomHandler::FenixProductFileGenerator.new("XYZ","23",true,"5 > 3")

      OpenChain::CustomHandler::FenixProductFileGenerator.should_receive(:new).with("XYZ","23",true,"5 > 3").and_return(fpfg)
      OpenChain::CustomHandler::FenixProductFileGenerator.any_instance.should_receive(:generate)
      OpenChain::CustomHandler::FenixProductFileGenerator.run_schedulable(hash)      
    end

    it "should not fail on missing options" do
      hash = {"fenix_customer_code" => "XYZ", "importer_id" => "23"}
      fpfg = OpenChain::CustomHandler::FenixProductFileGenerator.new("XYZ","23")

      OpenChain::CustomHandler::FenixProductFileGenerator.should_receive(:new).with("XYZ","23",false, nil).and_return(fpfg)
      OpenChain::CustomHandler::FenixProductFileGenerator.any_instance.should_receive(:generate)
      OpenChain::CustomHandler::FenixProductFileGenerator.run_schedulable(hash) 
    end
  end
end
