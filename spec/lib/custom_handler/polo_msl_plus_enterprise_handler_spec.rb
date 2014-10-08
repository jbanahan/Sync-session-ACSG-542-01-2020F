require 'spec_helper'

describe OpenChain::CustomHandler::PoloMslPlusEnterpriseHandler do
  after :each do
    File.delete @tmp if @tmp && File.exists?(@tmp)
  end
  describe :products_to_send do
    before :each do
      @cd_msl_rec = Factory(:custom_definition,:label=>"MSL+ Receive Date",:data_type=>"date",:module_type=>"Product")
      @cd_csm_num = Factory(:custom_definition,:label=>"CSM Number",:data_type=>:text,:module_type=>"Product")
      @p = Factory(:product)
    end
    it "should find product with MSL+ Receive Date" do
      @p.update_custom_value! @cd_msl_rec, 1.day.ago
      described_class.new.products_to_send.to_a.should == [@p]
    end
    it 'finds a product with a CSM Number' do
      @p.update_custom_value! @cd_csm_num, "CSM"
      described_class.new.products_to_send.to_a.should == [@p]
    end
    it "should not find product without MSL+ Receive Date or CSM Number" do
      described_class.new.products_to_send.to_a.should be_empty
    end
    it "should not find product that doesn't need sync" do
      @p.update_custom_value! @cd_msl_rec, 1.day.ago
      @p.update_attributes(:updated_at=>2.days.ago)
      @p.sync_records.create!(:trading_partner=>"MSLE",:sent_at=>1.day.ago,:confirmed_at=>1.hour.ago)
      described_class.new.products_to_send.to_a.should be_empty
    end
  end
  describe :outbound_file do
    before :each do
      # This example group takes a long time to run just due to the sheer number of custom values
      # created in here.
      @h = OpenChain::CustomHandler::PoloMslPlusEnterpriseHandler.new
      @t = Factory(:tariff_record,:hts_1=>"1234567890",:hts_2=>"0123456789",:hts_3=>"98765432")
      ['US','IT','CA','TW'].each {|iso| Factory(:country,:iso_code=>iso)}
      @c = @t.classification
      @p = @c.product
      @h.stub(:send_file)
    end

    it "should generate file with appropriate values" do
      custom_defs = @h.send(:init_outbound_custom_definitions)
      @p.update_custom_value! custom_defs[:length_cm], "1"
      @p.update_custom_value! custom_defs[:width_cm], "2"
      @p.update_custom_value! custom_defs[:height_cm], "3"
      @p.update_custom_value! custom_defs[:knit_woven], "k"
      @p.update_custom_value! custom_defs[:fiber_content], "fc"
      @p.update_custom_value! custom_defs[:common_name_1], "cn1"
      @p.update_custom_value! custom_defs[:common_name_2], "cn2"
      @p.update_custom_value! custom_defs[:common_name_3], "cn3"
      @p.update_custom_value! custom_defs[:scientific_name_1], "sn1"
      @p.update_custom_value! custom_defs[:scientific_name_2], "sn2"
      @p.update_custom_value! custom_defs[:scientific_name_3], "sn3"
      @p.update_custom_value! custom_defs[:fish_wildlife_origin_1], "fwo1"
      @p.update_custom_value! custom_defs[:fish_wildlife_origin_2], "fwo2"
      @p.update_custom_value! custom_defs[:fish_wildlife_origin_3], "fwo3"
      @p.update_custom_value! custom_defs[:fish_wildlife_source_1], "fws1"
      @p.update_custom_value! custom_defs[:fish_wildlife_source_2], "fws2"
      @p.update_custom_value! custom_defs[:fish_wildlife_source_3], "fws3"
      @p.update_custom_value! custom_defs[:origin_wildlife], "ow"
      @p.update_custom_value! custom_defs[:semi_precious], true
      @p.update_custom_value! custom_defs[:semi_precious_type], "spt"
      @p.update_custom_value! custom_defs[:cites], "cites"
      @p.update_custom_value! custom_defs[:fish_wildlife], false

      @tmp = @h.generate_outbound_sync_file Product.where("1=1")
      r = CSV.parse IO.read @tmp.path
      expect(r.length).to eq 2

      row = r[0]
      expect(row[0..8]).to eq ["Style", "Country", "MP1 Flag", "HTS 1", "HTS 2", "HTS 3", "Length", "Width", "Height"]
      counter = 8
      (1..15).each do |x|
        expect(row[counter+=1]).to eq "Fabric Type - #{x}"
        expect(row[counter+=1]).to eq "Fabric - #{x}"
        expect(row[counter+=1]).to eq "Fabric % - #{x}"
      end
      expect(row[54..row.length-1]).to eq ["Knit / Woven?", "Fiber Content %s", "Common Name 1", "Common Name 2", "Common Name 3", 
          "Scientific Name 1", "Scientific Name 2", "Scientific Name 3", "F&W Origin 1", "F&W Origin 2", "F&W Origin 3",
          "F&W Source 1", "F&W Source 2", "F&W Source 3", "Origin of Wildlife", "Semi-Precious", "Type of Semi-Precious", "CITES", "Fish & Wildlife"]

      row = r[1]
      row[0].should == @p.unique_identifier
      row[1].should == @c.country.iso_code
      row[2].should == '' #MP1
      row[3].should == @t.hts_1.hts_format
      row[4].should == @t.hts_2.hts_format
      row[5].should == @t.hts_3.hts_format
      row[6].should == "1.0" #length
      row[7].should == "2.0" #width
      row[8].should == "3.0" #height
      # Fabric Fields are all nil
      (9..53).each {|x| expect(row[x]).to be_nil}
      expect(row[54..72]).to eq ["k", "fc", "cn1", "cn2", "cn3", "sn1", "sn2", "sn3", "fwo1", "fwo2", "fwo3", "fws1", "fws2", "fws3", "ow", "true", "spt", "cites", "false"]
    end

    it "should handle multiple products" do
      tr2 = Factory(:tariff_record,:hts_1=>'123456')
      @tmp = @h.generate_outbound_sync_file [@p,tr2.product]
      r = CSV.parse IO.read @tmp.path
      r.should have(3).rows
      r[1][0].should == @p.unique_identifier
      r[2][0].should == tr2.product.unique_identifier
    end
    it "should handle multple countries" do
      tr2 = Factory(:tariff_record,:classification=>Factory(:classification,:product=>@p),:hts_1=>'654321')
      @tmp = @h.generate_outbound_sync_file [@p]
      r = CSV.parse IO.read @tmp.path
      r.should have(3).rows
      r[1][0].should == @p.unique_identifier
      r[2][0].should == @p.unique_identifier
      r[1][1].should == @c.country.iso_code
      r[2][1].should == tr2.classification.country.iso_code
      r[1][3].should == '1234567890'.hts_format
      r[2][3].should == '654321'.hts_format
    end
    it "should not send US, Canada" do
      ['US','CA', 'IT'].each do |iso|
        Factory(:tariff_record,:classification=>Factory(:classification,:country=>Country.find_by_iso_code(iso),:product=>@p),:hts_1=>'654321')
      end
      @p.reload
      @p.classifications.count.should == 4
      @tmp = @h.generate_outbound_sync_file [@p]
      r = CSV.parse IO.read @tmp.path
      r.should have(3).rows
      r[1][1].should == @c.country.iso_code
    end
    it "should remove periods from Taiwan tariffs" do
      tr = Factory(:tariff_record,:classification=>Factory(:classification,:country=>Country.find_by_iso_code('TW')),:hts_1=>'65432101')
      @tmp = @h.generate_outbound_sync_file [tr.product]
      r = CSV.parse IO.read @tmp.path
      r.should have(2).rows
      r[1][1].should == 'TW'
      r[1][3].should == '65432101'
    end
    it "should set MP1 flag for Taiwan tariff with flag set" do
      Factory(:official_tariff,:country=>Country.find_by_iso_code('TW'),:hts_code=>'65432101',:import_regulations=>"ABC MP1 DEF")
      tr = Factory(:tariff_record,:classification=>Factory(:classification,:country=>Country.find_by_iso_code('TW')),:hts_1=>'65432101')
      @tmp = @h.generate_outbound_sync_file [tr.product]
      r = CSV.parse IO.read @tmp.path
      r.should have(2).rows
      r[1][1].should == 'TW'
      r[1][2].should == 'true'
      r[1][3].should == '65432101'
    end
    it "should create new sync_records" do
      @tmp = @h.generate_outbound_sync_file [@p]
      @p.reload
      @p.should have(1).sync_records
      sr = @p.sync_records.first
      sr.trading_partner.should == "MSLE"
      sr.sent_at.should > 3.seconds.ago
      sr.confirmed_at.should be_nil
    end
    it "should update sent_at time for existing sync_records" do
      @p.sync_records.create!(:trading_partner=>"MSLE",:sent_at=>1.day.ago)
      @tmp = @h.generate_outbound_sync_file [@p]
      @p.reload
      @p.should have(1).sync_records
      sr = @p.sync_records.first
      sr.trading_partner.should == "MSLE"
      sr.sent_at.should > 3.seconds.ago
      sr.confirmed_at.should be_nil
    end
    it 'should send file to ftp folder' do
      override_time = DateTime.new(2010,1,2,3,4,5)
      @tmp = Tempfile.new('x')
      @h.should_receive(:send_file).with(@tmp,"ChainIO_HTSExport_20100102030405.csv")
      @h.send_and_delete_sync_file @tmp, override_time
      File.exists?(@tmp.path).should be_false
      @tmp = nil
    end

    it "strips newlines from values" do
      custom_defs = @h.send(:init_outbound_custom_definitions)
      @p.update_custom_value! custom_defs[:fiber_content], "1\r\n2\n3"

      @tmp = @h.generate_outbound_sync_file Product.where("1=1")
      r = CSV.parse IO.read @tmp.path

      expect(r[1][55]).to eq "1 2 3"
    end

    it "orders tariff records by line number" do
      t2 = Factory(:tariff_record, hts_1: "987654321", classification: @c, line_number: 2)
      @t.update_attributes! line_number: 3
      
      @tmp = @h.generate_outbound_sync_file Product.where("1=1")
      r = CSV.parse IO.read @tmp.path
      expect(r[1][3]).to eq t2.hts_1.hts_format
    end
  end
  describe :send_file do
    it 'should send file' do
      @tmp = Tempfile.new('y')
      fn = 'abc.txt'
      FtpSender.should_receive(:send_file).with("connect.vfitrack.net","polo","pZZ117",@tmp,{:folder=>'/_to_msl',:remote_file_name=>fn})
      OpenChain::CustomHandler::PoloMslPlusEnterpriseHandler.new.send_file(@tmp,fn)
    end
    it 'should send file in qa_mode' do
      @tmp = Tempfile.new('y')
      fn = 'abc.txt'
      FtpSender.should_receive(:send_file).with("connect.vfitrack.net","polo","pZZ117",@tmp,{:folder=>'/_test_to_msl',:remote_file_name=>fn})
      OpenChain::CustomHandler::PoloMslPlusEnterpriseHandler.new(:env=>:qa).send_file(@tmp,fn)
    end
  end
  describe :inbound_file do
    before :each do
      @file_content = "US Style Number,US Season,Board Number,Item Description,US Model Description,GCC Style Description,HTS Description 1,HTS Description 2,HTS Description 3,AX Sub Class,US Brand,US Sub Brand,US Class
7352024LTBR,F12,O26SC10,LEATHER BARRACUDA-POLYESTER,LEATHER BARRACUDA,Men's Jacket,100% Real Lambskin Men's Jacket,TESTHTS2,TESTHTS3,Suede/Leather Outerwear,Menswear,POLO SPORTSWEAR,OUTERWEAR
3221691177NY,S13,,SS BIG PP POLO SHIRT-MESH,SS BIG PP POLO SHIRT,Boys Knit Shirt,100% COTTON Boys Knit Shirt,,,SS Big Pony Mesh,Childrenswear,BOYS 4-7,KNITS
322169117JAL,S13,,SS BIG PP POLO SHIRT-MESH,SS BIG PP POLO SHIRT,Boys Knit Shirt,100% COTTON Boys Knit Shirt,,,SS Big Pony Mesh,Childrenswear,BOYS 4-7,KNITS
443590,S13,K21RB05,SS SLD JRSY CN PK,SS SLD JRSY CN PK,Men's Knit T-Shirt,100% COTTON Men's Knit T-Shirt,,,,Menswear,MENS RRL,KNITS
4371543380AX,NOS,,DOUBLE HANDLE ATTACHE-ALLIGATOR,DOUBLE HANDLE ATTACHE,Handbag,100% Crocodile Handbag,,,Business Case,Leathergoods,MEN'S COLLECTION BAGS,EXOTIC BAGS"
      @h = OpenChain::CustomHandler::PoloMslPlusEnterpriseHandler.new
      @style_numbers = ["7352024LTBR","3221691177NY","322169117JAL","443590","4371543380AX"]
      @h.stub(:send_file)
    end
    
    it "should write new product" do
      @tmp = @h.process @file_content
      Product.count.should == 5
      Product.all.collect {|p| p.unique_identifier}.should == @style_numbers 
      p = Product.where(:unique_identifier=>"7352024LTBR").includes(:custom_values).first
      cdefs = @h.send(:init_inbound_custom_definitions)

      p.get_custom_value(cdefs[:msl_board_number]).value.should == "O26SC10"
      p.get_custom_value(cdefs[:msl_gcc_desc]).value.should =='Men\'s Jacket'
      p.get_custom_value(cdefs[:msl_hts_desc]).value.should =='100% Real Lambskin Men\'s Jacket'
      p.get_custom_value(cdefs[:msl_us_season]).value.should =='F12'
      p.get_custom_value(cdefs[:msl_item_desc]).value.should =='LEATHER BARRACUDA-POLYESTER'
      p.get_custom_value(cdefs[:msl_model_desc]).value.should =='LEATHER BARRACUDA'
      p.get_custom_value(cdefs[:msl_hts_desc_2]).value.should =='TESTHTS2'
      p.get_custom_value(cdefs[:msl_hts_desc_3]).value.should =='TESTHTS3'
      p.get_custom_value(cdefs[:ax_subclass]).value.should =='Suede/Leather Outerwear'
      p.get_custom_value(cdefs[:msl_us_brand]).value.should =='Menswear'
      p.get_custom_value(cdefs[:msl_us_sub_brand]).value.should =='POLO SPORTSWEAR'
      p.get_custom_value(cdefs[:msl_us_class]).value.should =='OUTERWEAR'
      p.get_custom_value(cdefs[:msl_receive_date]).value.should == Date.today 
    end
    it "should update existing product" do
      cdefs = @h.send(:init_inbound_custom_definitions)
      p = Product.create!(:unique_identifier=>"7352024LTBR")
      p.update_custom_value! cdefs[:msl_board_number], "ABC"
      p.update_custom_value! cdefs[:msl_receive_date], 1.year.ago
      @tmp = @h.process @file_content
      p = Product.find_by_unique_identifier("7352024LTBR")
      p.get_custom_value(cdefs[:msl_board_number]).value.should == "O26SC10"
      p.get_custom_value(cdefs[:msl_receive_date]).value.should == Date.today 
    end
    it "should generate acknowledgement file" do
      @tmp = @h.process @file_content
      r = CSV.parse IO.read @tmp.path
      r.should have(6).rows
      r[0].should == ['Style','Time Processed','Status']
      @style_numbers.each_with_index do |s,i|
        r[i+1][0].should == s
      end
      r.each_with_index do |row,i|
        next if i==0
        DateTime.strptime(row[1],"%Y%m%d%H%M%S").should > (Time.now-2.minutes)
        row[2].should == "OK"
      end
    end
    it "should write CSV parse failure to acknowledgement file" do
      CSV.stub(:parse).and_raise("PROCFAIL")
      @tmp = @h.process @file_content
      tmp_content = IO.readlines @tmp.path
      tmp_content[1].should == "INVALID CSV FILE ERROR: PROCFAIL"
    end
    it "should write error in processing product to acknowledgement file and keep processing" do
      Product.should_receive(:find_or_create_by_unique_identifier).with("7352024LTBR").and_raise("PERROR")
      ['3221691177NY','322169117JAL','443590','4371543380AX'].each do |g|
        Product.should_receive(:find_or_create_by_unique_identifier).
          with(g).and_return(Product.create(:unique_identifier=>g))
      end
      @tmp = @h.process @file_content
      tmp_content = CSV.parse IO.read @tmp.path
      tmp_content[1][2].should == "PERROR"
      tmp_content[2][0].should == "3221691177NY" 
    end
    it "should FTP acknowledgement file" do
      @tmp = File.new('spec/support/tmp/abc.csv','w')
      @tmp << 'ABC'
      @tmp.flush
      @h.should_receive(:send_file).with(@tmp,'abc-ack.csv')
      @h.send_and_delete_ack_file @tmp, 'abc.csv'
      File.exists?(@tmp.path).should be_false
      @tmp = nil
    end
  end
end