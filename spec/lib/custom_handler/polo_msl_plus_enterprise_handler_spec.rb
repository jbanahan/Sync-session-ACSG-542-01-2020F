require 'spec_helper'

describe OpenChain::CustomHandler::PoloMslPlusEnterpriseHandler do
  after :each do
    File.delete @tmp if @tmp && File.exists?(@tmp)
  end
  describe "products_to_send" do
    before :all do
      @custom_defs = described_class.new.send(:init_outbound_custom_definitions)
    end
    after :all do
      CustomDefinition.scoped.destroy_all
      @custom_defs = nil
    end
    before :each do
      cdefs = described_class.prep_custom_definitions [:msl_receive_date,:csm_numbers]
      @cd_msl_rec = cdefs[:msl_receive_date]
      @cd_csm_num = cdefs[:csm_numbers]
      @countries = {}
      ['US','IT','CA','TW'].each {|iso| @countries[iso] = Factory(:country,:iso_code=>iso)}
      t = Factory(:tariff_record, classification: Factory(:classification, country: @countries['IT']))
      @p = t.product
      expect_any_instance_of(described_class).to receive(:init_outbound_custom_definitions).and_call_original
    end
    it "should find product with MSL+ Receive Date having non-US, CA tariffs" do
      @p.update_custom_value! @cd_msl_rec, 1.day.ago
      expect(described_class.new.products_to_send.to_a).to eq([@p])
    end
    it 'finds a product with a CSM Number' do
      @p.update_custom_value! @cd_csm_num, "CSM"
      expect(described_class.new.products_to_send.to_a).to eq([@p])
    end
    it "should not find product without MSL+ Receive Date or CSM Number" do
      expect(described_class.new.products_to_send.to_a).to be_empty
    end
    it "should not find product that doesn't need sync" do
      @p.update_custom_value! @cd_msl_rec, 1.day.ago
      @p.update_attributes(:updated_at=>2.days.ago)
      @p.sync_records.create!(:trading_partner=>"MSLE",:sent_at=>1.day.ago,:confirmed_at=>1.hour.ago)
      expect(described_class.new.products_to_send.to_a).to be_empty
    end
    it "should not find a product that only has US and CA tariffs" do
      @p.classifications.destroy_all
      t = Factory(:tariff_record, classification: Factory(:classification, country: @countries['CA'], product: @p))
      t2 = Factory(:tariff_record, classification: Factory(:classification, country: @countries['US'], product: @p))

      expect(described_class.new.products_to_send.to_a).to be_empty
    end
    it "should not find a product that only has US and CA tariffs" do
      @p.classifications.destroy_all
      t = Factory(:tariff_record, classification: Factory(:classification, country: @countries['CA'], product: @p))
      t2 = Factory(:tariff_record, classification: Factory(:classification, country: @countries['US'], product: @p))

      expect(described_class.new.products_to_send.to_a).to be_empty
    end
    it "should find a product that does not have a tariff record" do
      @p.update_custom_value! @cd_msl_rec, 1.day.ago
      @p.classifications.first.tariff_records.destroy_all
      expect(described_class.new.products_to_send).to include @p
    end
    it "finds a record that does not have a classfiication" do
      @p.classifications.destroy_all
      @p.update_custom_value! @cd_msl_rec, 1.day.ago
      expect(described_class.new.products_to_send).to include @p
    end
  end
  describe "outbound_file" do
    before :all do
      @custom_defs = described_class.new.send(:init_outbound_custom_definitions)
    end
    after :all do
      CustomDefinition.scoped.destroy_all
      @custom_defs = nil
    end
    before :each do
      # This example group takes a long time to run just due to the sheer number of custom values
      # created in here.
      @h = OpenChain::CustomHandler::PoloMslPlusEnterpriseHandler.new
      @t = Factory(:tariff_record,:hts_1=>"1234567890",:hts_2=>"0123456789",:hts_3=>"98765432")
      ['US','IT','CA','TW'].each {|iso| Factory(:country,:iso_code=>iso)}
      @c = @t.classification
      @p = @c.product
      allow(@h).to receive(:send_file)
    end

    it "should generate file with appropriate values" do
      custom_defs = @custom_defs
      @p.update_custom_value! custom_defs[:length_cm], "1"
      @p.update_custom_value! custom_defs[:width_cm], "2"
      @p.update_custom_value! custom_defs[:height_cm], "3"
      @p.update_custom_value! custom_defs[:material_group], "k"
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
      @p.update_custom_value! custom_defs[:cites], true
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
      expect(row[0]).to eq(@p.unique_identifier)
      expect(row[1]).to eq(@c.country.iso_code)
      expect(row[2]).to eq('') #MP1
      expect(row[3]).to eq(@t.hts_1.hts_format)
      expect(row[4]).to eq(@t.hts_2.hts_format)
      expect(row[5]).to eq(@t.hts_3.hts_format)
      expect(row[6]).to eq("1") #length
      expect(row[7]).to eq("2") #width
      expect(row[8]).to eq("3") #height
      # Fabric Fields are all nil
      (9..53).each {|x| expect(row[x]).to be_nil}
      expect(row[54..72]).to eq ["k", "fc", "cn1", "cn2", "cn3", "sn1", "sn2", "sn3", "fwo1", "fwo2", "fwo3", "fws1", "fws2", "fws3", "ow", "true", "spt", "true", "false"]
    end

    it "should handle multiple products" do
      tr2 = Factory(:tariff_record,:hts_1=>'123456')
      @tmp = @h.generate_outbound_sync_file [@p,tr2.product]
      r = CSV.parse IO.read @tmp.path
      expect(r.size).to eq(3)
      expect(r[1][0]).to eq(@p.unique_identifier)
      expect(r[2][0]).to eq(tr2.product.unique_identifier)
    end
    it "should handle multple countries" do
      tr2 = Factory(:tariff_record,:classification=>Factory(:classification,:product=>@p),:hts_1=>'654321')
      @tmp = @h.generate_outbound_sync_file [@p]
      r = CSV.parse IO.read @tmp.path
      expect(r.size).to eq(3)
      expect(r[1][0]).to eq(@p.unique_identifier)
      expect(r[2][0]).to eq(@p.unique_identifier)
      expect(r[1][1]).to eq(@c.country.iso_code)
      expect(r[2][1]).to eq(tr2.classification.country.iso_code)
      expect(r[1][3]).to eq('1234567890'.hts_format)
      expect(r[2][3]).to eq('654321'.hts_format)
    end
    it "should not send US, Canada" do
      ['US','CA', 'IT'].each do |iso|
        Factory(:tariff_record,:classification=>Factory(:classification,:country=>Country.find_by_iso_code(iso),:product=>@p),:hts_1=>'654321')
      end
      @p.reload
      expect(@p.classifications.count).to eq(4)
      @tmp = @h.generate_outbound_sync_file [@p]
      r = CSV.parse IO.read @tmp.path
      expect(r.size).to eq(3)
      expect(r[1][1]).to eq(@c.country.iso_code)
    end
    it "should remove periods from Taiwan tariffs" do
      tr = Factory(:tariff_record,:classification=>Factory(:classification,:country=>Country.find_by_iso_code('TW')),:hts_1=>'65432101')
      @tmp = @h.generate_outbound_sync_file [tr.product]
      r = CSV.parse IO.read @tmp.path
      expect(r.size).to eq(2)
      expect(r[1][1]).to eq('TW')
      expect(r[1][3]).to eq('65432101')
    end
    it "should set MP1 flag for Taiwan tariff with flag set" do
      Factory(:official_tariff,:country=>Country.find_by_iso_code('TW'),:hts_code=>'65432101',:import_regulations=>"ABC MP1 DEF")
      tr = Factory(:tariff_record,:classification=>Factory(:classification,:country=>Country.find_by_iso_code('TW')),:hts_1=>'65432101')
      @tmp = @h.generate_outbound_sync_file [tr.product]
      r = CSV.parse IO.read @tmp.path
      expect(r.size).to eq(2)
      expect(r[1][1]).to eq('TW')
      expect(r[1][2]).to eq('true')
      expect(r[1][3]).to eq('65432101')
    end
    it "should create new sync_records" do
      @tmp = @h.generate_outbound_sync_file [@p]
      @p.reload
      expect(@p.sync_records.size).to eq(1)
      sr = @p.sync_records.first
      expect(sr.trading_partner).to eq("MSLE")
      expect(sr.sent_at).to be > 3.seconds.ago
      expect(sr.confirmed_at).to be_nil
    end
    it "should update sent_at time for existing sync_records" do
      @p.sync_records.create!(:trading_partner=>"MSLE",:sent_at=>1.day.ago)
      @tmp = @h.generate_outbound_sync_file [@p]
      @p.reload
      expect(@p.sync_records.size).to eq(1)
      sr = @p.sync_records.first
      expect(sr.trading_partner).to eq("MSLE")
      expect(sr.sent_at).to be > 3.seconds.ago
      expect(sr.confirmed_at).to be_nil
    end
    it 'should send file to ftp folder' do
      override_time = DateTime.new(2010,1,2,3,4,5)
      @tmp = Tempfile.new('x')
      expect(@h).to receive(:send_file).with(@tmp,"ChainIO_HTSExport_20100102030405.csv")
      @h.send_and_delete_sync_file @tmp, override_time
      expect(File.exists?(@tmp.path)).to be_falsey
      @tmp = nil
    end

    it "strips newlines from values" do
      custom_defs = @custom_defs
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

    it "sends fiber fields if barthco id is not blank/blocked, msl_fiber_failure is falsy, msl_us_class isn't on blacklist" do
      # Just use the first and last fiber fields, otherwise the whole process takes WAY too long to generate
      # 45 new fields
      custom_defs = @custom_defs
      @p.update_custom_value! custom_defs[:bartho_customer_id], "ID"
      @p.update_custom_value! custom_defs[:msl_fiber_failure], nil
      @p.update_custom_value! custom_defs[:msl_us_class], "not on list"

      @p.update_custom_value! custom_defs[:fabric_type_1], "Fabric Type 1"
      @p.update_custom_value! custom_defs[:fabric_1], "Fabric 1"
      @p.update_custom_value! custom_defs[:fabric_percent_1], 1
      @p.update_custom_value! custom_defs[:fabric_percent_15], 15.123


      @tmp = @h.generate_outbound_sync_file Product.where("1=1")
      r = CSV.parse IO.read @tmp.path
      row = r[1]
      expect(row[9]).to eq "Fabric Type 1"
      expect(row[10]).to eq "Fabric 1"
      expect(row[11]).to eq "1"
      expect(row[53]).to eq "15.12"
    end

    it "does not send fiber fields if barthco id is blocked" do
      custom_defs = @custom_defs
      @p.update_custom_value! custom_defs[:bartho_customer_id], "48650"
      @p.update_custom_value! custom_defs[:msl_fiber_failure], nil
      @p.update_custom_value! custom_defs[:msl_us_class], "not on list"
      @p.update_custom_value! custom_defs[:fabric_type_1], "Fabric Type 1"
      @p.update_custom_value! custom_defs[:fabric_percent_15], 15

      @tmp = @h.generate_outbound_sync_file Product.where("1=1")
      r = CSV.parse IO.read @tmp.path
      (9..53).each {|x| expect(r[1][x]).to be_nil}
    end

    it "does not send fiber fields if barthco id blank" do
      custom_defs = @custom_defs
      @p.update_custom_value! custom_defs[:bartho_customer_id], nil
      @p.update_custom_value! custom_defs[:msl_fiber_failure], nil
      @p.update_custom_value! custom_defs[:msl_us_class], "not on list"
      @p.update_custom_value! custom_defs[:fabric_type_1], "Fabric Type 1"
      @p.update_custom_value! custom_defs[:fabric_percent_15], 15

      @tmp = @h.generate_outbound_sync_file Product.where("1=1")
      r = CSV.parse IO.read @tmp.path
      (9..53).each {|x| expect(r[1][x]).to be_nil}
    end

    it "does not send fiber fields if msl_fiber_failure is true" do
      custom_defs = @custom_defs
      @p.update_custom_value! custom_defs[:bartho_customer_id], "ID"
      @p.update_custom_value! custom_defs[:msl_fiber_failure], true
      @p.update_custom_value! custom_defs[:msl_us_class], "not on list"
      @p.update_custom_value! custom_defs[:fabric_type_1], "Fabric Type 1"
      @p.update_custom_value! custom_defs[:fabric_percent_15], 15

      @tmp = @h.generate_outbound_sync_file Product.where("1=1")
      r = CSV.parse IO.read @tmp.path
      (9..53).each {|x| expect(r[1][x]).to be_nil}
    end

    it "does not send fiber fields if msl_us_class is blocked" do
      custom_defs = @custom_defs
      @p.update_custom_value! custom_defs[:bartho_customer_id], "ID"
      @p.update_custom_value! custom_defs[:msl_fiber_failure], nil
      @p.update_custom_value! custom_defs[:msl_us_class], "Bracelet"
      @p.update_custom_value! custom_defs[:fabric_type_1], "Fabric Type 1"
      @p.update_custom_value! custom_defs[:fabric_percent_15], 15

      @tmp = @h.generate_outbound_sync_file Product.where("1=1")
      r = CSV.parse IO.read @tmp.path
      (9..53).each {|x| expect(r[1][x]).to be_nil}
    end

    it "does not send fiber fields fiber parser failed to parse the fiber content field" do
      custom_defs = @custom_defs
      @p.update_custom_value! custom_defs[:bartho_customer_id], "ID"
      @p.update_custom_value! custom_defs[:fabric_type_1], "Fabric Type 1"
      @p.update_custom_value! custom_defs[:fabric_percent_15], 15
      @p.update_custom_value! custom_defs[:msl_fiber_failure], true

      @tmp = @h.generate_outbound_sync_file Product.where("1=1")
      r = CSV.parse IO.read @tmp.path
      (9..53).each {|x| expect(r[1][x]).to be_nil}
    end

    it "sends a row with blank tariff information if no tariff records associated w/ classification " do
      @t.destroy
      @tmp = @h.generate_outbound_sync_file Product.where("1=1")
      r = CSV.parse IO.read @tmp.path

      # Verify blanks in the tariff data are present
      expect(r[1][0]).to eq @p.unique_identifier
      expect(r[1][2]).to be_blank
      expect(r[1][3]).to be_blank
      expect(r[1][4]).to be_blank
      expect(r[1][5]).to be_blank
    end

    it "sends a row with blank tariff information if no tariff records associated w/ classification for taiwan" do
      @t.destroy
      @c.update_attributes! country: Country.where(iso_code: "TW").first
      @tmp = @h.generate_outbound_sync_file Product.where("1=1")
      r = CSV.parse IO.read @tmp.path

      # Verify blanks in the tariff data are present
      expect(r[1][0]).to eq @p.unique_identifier
      expect(r[1][2]).to be_blank
      expect(r[1][3]).to be_blank
      expect(r[1][4]).to be_blank
      expect(r[1][5]).to be_blank
    end

    it "sends a row with blank country information if no classifications are present" do
      @c.destroy

      @tmp = @h.generate_outbound_sync_file Product.where("1=1")
      r = CSV.parse IO.read @tmp.path

      # Verify blanks in the tariff data are present, and country is defaulted to CN
      expect(r[1][0]).to eq @p.unique_identifier
      expect(r[1][1]).to eq "CN"
      expect(r[1][2]).to be_blank
      expect(r[1][3]).to be_blank
      expect(r[1][4]).to be_blank
      expect(r[1][5]).to be_blank
    end
  end
  describe "send_file" do
    it 'should send file' do
      @tmp = Tempfile.new('y')
      fn = 'abc.txt'
      expect(FtpSender).to receive(:send_file).with("connect.vfitrack.net","polo","pZZ117",@tmp,{:folder=>'/_to_msl',:remote_file_name=>fn})
      OpenChain::CustomHandler::PoloMslPlusEnterpriseHandler.new.send_file(@tmp,fn)
    end
    it 'should send file in qa_mode' do
      @tmp = Tempfile.new('y')
      fn = 'abc.txt'
      expect(FtpSender).to receive(:send_file).with("connect.vfitrack.net","polo","pZZ117",@tmp,{:folder=>'/_test_to_msl',:remote_file_name=>fn})
      OpenChain::CustomHandler::PoloMslPlusEnterpriseHandler.new(:env=>:qa).send_file(@tmp,fn)
    end
  end
  describe "inbound_file" do
    before :all do
      @custom_defs = described_class.new.send(:init_inbound_custom_definitions)
    end
    after :all do
      @custom_defs = nil
      CustomDefinition.destroy_all
    end
    before :each do
      @file_content = "US Style Number,US Season,Board Number,Item Description,US Model Description,GCC Style Description,HTS Description 1,HTS Description 2,HTS Description 3,AX Sub Class,US Brand,US Sub Brand,US Class
7352024LTBR,F12,O26SC10,LEATHER BARRACUDA-POLYESTER,LEATHER BARRACUDA,Men's Jacket,100% Real Lambskin Men's Jacket,TESTHTS2,TESTHTS3,Suede/Leather Outerwear,Menswear,POLO SPORTSWEAR,OUTERWEAR
3221691177NY,S13,,SS BIG PP POLO SHIRT-MESH,SS BIG PP POLO SHIRT,Boys Knit Shirt,100% COTTON Boys Knit Shirt,,,SS Big Pony Mesh,Childrenswear,BOYS 4-7,KNITS
322169117JAL,S13,,SS BIG PP POLO SHIRT-MESH,SS BIG PP POLO SHIRT,Boys Knit Shirt,100% COTTON Boys Knit Shirt,,,SS Big Pony Mesh,Childrenswear,BOYS 4-7,KNITS
443590,S13,K21RB05,SS SLD JRSY CN PK,SS SLD JRSY CN PK,Men's Knit T-Shirt,100% COTTON Men's Knit T-Shirt,,,,Menswear,MENS RRL,KNITS
4371543380AX,NOS,,DOUBLE HANDLE ATTACHE-ALLIGATOR,DOUBLE HANDLE ATTACHE,Handbag,100% Crocodile Handbag,,,Business Case,Leathergoods,MEN'S COLLECTION BAGS,EXOTIC BAGS"
      @h = OpenChain::CustomHandler::PoloMslPlusEnterpriseHandler.new
      @style_numbers = ["7352024LTBR","3221691177NY","322169117JAL","443590","4371543380AX"]
      allow(@h).to receive(:send_file)
    end

    it "should write new product" do
      @tmp = @h.process @file_content
      expect(Product.count).to eq(5)
      expect(Product.all.collect {|p| p.unique_identifier}).to eq(@style_numbers)
      p = Product.where(:unique_identifier=>"7352024LTBR").includes(:custom_values).first
      cdefs = @custom_defs

      expect(p.get_custom_value(cdefs[:msl_board_number]).value).to eq("O26SC10")
      expect(p.get_custom_value(cdefs[:msl_gcc_desc]).value).to eq("Men's Jacket")
      expect(p.get_custom_value(cdefs[:msl_hts_desc]).value).to eq("100% Real Lambskin Men's Jacket")
      expect(p.get_custom_value(cdefs[:msl_us_season]).value).to eq('F12')
      expect(p.get_custom_value(cdefs[:msl_item_desc]).value).to eq('LEATHER BARRACUDA-POLYESTER')
      expect(p.get_custom_value(cdefs[:msl_model_desc]).value).to eq('LEATHER BARRACUDA')
      expect(p.get_custom_value(cdefs[:msl_hts_desc_2]).value).to eq('TESTHTS2')
      expect(p.get_custom_value(cdefs[:msl_hts_desc_3]).value).to eq('TESTHTS3')
      expect(p.get_custom_value(cdefs[:ax_subclass]).value).to eq('Suede/Leather Outerwear')
      expect(p.get_custom_value(cdefs[:msl_us_brand]).value).to eq('Menswear')
      expect(p.get_custom_value(cdefs[:msl_us_sub_brand]).value).to eq('POLO SPORTSWEAR')
      expect(p.get_custom_value(cdefs[:msl_us_class]).value).to eq('OUTERWEAR')
      expect(p.get_custom_value(cdefs[:msl_receive_date]).value).to eq(Date.today)

      expect(p.entity_snapshots.size).to eq 1
      expect(p.last_updated_by).to eq User.integration
    end
    it "should update existing product" do
      cdefs = @custom_defs
      p = Product.create!(:unique_identifier=>"7352024LTBR")
      p.update_custom_value! cdefs[:msl_board_number], "ABC"
      p.update_custom_value! cdefs[:msl_receive_date], 1.year.ago
      @tmp = @h.process @file_content
      p = Product.find_by_unique_identifier("7352024LTBR")
      expect(p.get_custom_value(cdefs[:msl_board_number]).value).to eq("O26SC10")
      expect(p.get_custom_value(cdefs[:msl_receive_date]).value).to eq(Date.today)
      expect(p.entity_snapshots.size).to eq 1
      expect(p.last_updated_by).to eq User.integration
    end
    it "should generate acknowledgement file" do
      @tmp = @h.process @file_content
      r = CSV.parse IO.read @tmp.path
      expect(r.size).to eq(6)
      expect(r[0]).to eq(['Style','Time Processed','Status'])
      @style_numbers.each_with_index do |s,i|
        expect(r[i+1][0]).to eq(s)
      end
      r.each_with_index do |row,i|
        next if i==0
        expect(DateTime.strptime(row[1],"%Y%m%d%H%M%S")).to be > (Time.now-2.minutes)
        expect(row[2]).to eq("OK")
      end
    end
    it "should write CSV parse failure to acknowledgement file" do
      allow(CSV).to receive(:parse).and_raise("PROCFAIL")
      @tmp = @h.process @file_content
      tmp_content = IO.readlines @tmp.path
      expect(tmp_content[1]).to eq("INVALID CSV FILE ERROR: PROCFAIL")
    end
    it "should write error in processing product to acknowledgement file and keep processing" do
      expect(Product).to receive(:find_or_create_by_unique_identifier).with("7352024LTBR").and_raise("PERROR")
      ['3221691177NY','322169117JAL','443590','4371543380AX'].each do |g|
        expect(Product).to receive(:find_or_create_by_unique_identifier).
          with(g).and_return(Product.create(:unique_identifier=>g))
      end
      @tmp = @h.process @file_content
      tmp_content = CSV.parse IO.read @tmp.path
      expect(tmp_content[1][2]).to eq("PERROR")
      expect(tmp_content[2][0]).to eq("3221691177NY")
    end
    it "should FTP acknowledgement file" do
      file = instance_double(File)
      expect(@h).to receive(:send_file).with(file, 'abc-ack.csv')
      expect(File).to receive(:delete).with file
      @h.send_and_delete_ack_file file, 'abc.csv'
    end
  end

  describe "send_and_delete_ack_file_from_s3" do
    before :each do
      @contents = "File Contents"
      @tempfile = Tempfile.new ['file', '.txt']
      @tempfile << @contents
      @tempfile.flush
    end

    after :each do
      @tempfile.close! unless @tempfile.closed?
    end

    it "processes an a msl plus file and forwards an ack file on" do
      expect(OpenChain::S3).to receive(:download_to_tempfile).with("bucket", "file").and_yield @tempfile
      expect_any_instance_of(described_class).to receive(:process).with(@contents).and_return "Processed"
      expect_any_instance_of(described_class).to receive(:send_and_delete_ack_file).with("Processed", "original.txt")

      described_class.send_and_delete_ack_file_from_s3 'bucket', 'file', 'original.txt'
    end
  end
end
