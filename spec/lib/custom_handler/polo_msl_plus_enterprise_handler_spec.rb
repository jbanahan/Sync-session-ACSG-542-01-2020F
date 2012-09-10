require 'spec_helper'

describe OpenChain::CustomHandler::PoloMslPlusEnterpriseHandler do
  after :each do
    @tmp.unlink if @tmp
  end
  describe :process_ack_from_msl do
    before :each do
      @p = Factory(:product)
      @sent_time = Time.now
      @p.sync_records.create!(:sent_at=>@sent_time,:trading_partner=>'MSLE')
      @tmp = Tempfile.new(['ack','.csv'])
      @tmp << ['Style','Time Processed','Status'].to_csv
      @h = OpenChain::CustomHandler::PoloMslPlusEnterpriseHandler.new
    end
    it 'should update sync record' do
      @tmp << [@p.unique_identifier,Time.now,'OK'].to_csv
      @tmp.flush
      @h.should_not_receive(:email_ack_failures)
      @h.process_ack_from_msl IO.read(@tmp.path), 'a.csv'
      @p.reload
      @p.should have(1).sync_records
      sr = @p.sync_records.first
      sr.sent_at.to_i.should == @sent_time.to_i
      sr.confirmed_at.should > 2.seconds.ago
      sr.trading_partner.should == 'MSLE'
      sr.confirmation_file_name.should == 'a.csv'
      sr.failure_message.should be_blank
    end
    it 'should have error when status not OK' do
      @tmp << [@p.unique_identifier,Time.now,'BADSTYLE'].to_csv
      @tmp.flush
      @h.should_receive(:email_ack_failures).with(IO.read(@tmp.path),'a.csv',["Style #{@p.unique_identifier} failed: BADSTYLE"])
      @h.process_ack_from_msl IO.read(@tmp.path), 'a.csv'
      sr = @p.sync_records.first
      sr.confirmed_at.should > 2.seconds.ago
      sr.trading_partner.should == 'MSLE'
      sr.confirmation_file_name.should == 'a.csv'
      sr.failure_message.should == 'BADSTYLE'
    end
    it "should have error if product doesn't exist" do
      @tmp << ["#{@p.unique_identifier}nogood",Time.now,'OK'].to_csv
      @tmp.flush
      @h.should_receive(:email_ack_failures).with(IO.read(@tmp.path),'a.csv',["Style #{@p.unique_identifier}nogood confirmed, but it does not exist."])
      @h.process_ack_from_msl IO.read(@tmp.path), 'a.csv'
    end
    it "should have error if sync record doesn't exist" do
      @p.sync_records.destroy_all
      @tmp << [@p.unique_identifier,Time.now,'OK'].to_csv
      @tmp.flush
      @h.should_receive(:email_ack_failures).with(IO.read(@tmp.path),'a.csv',["Style #{@p.unique_identifier} confirmed, but it was never sent."])
      @h.process_ack_from_msl IO.read(@tmp.path), 'a.csv'
    end
    it 'should email failed records with attachment' do
      @tmp << [@p.unique_identifier,Time.now,'BADSTYLE'].to_csv
      @tmp.flush
      @h.process_ack_from_msl IO.read(@tmp.path), 'a.csv'
      mail = ActionMailer::Base.deliveries.pop
      mail.to.should == ['bug@aspect9.com']
      mail.subject.should == "[Chain.io] MSL+ Enterprise Product Sync Failure"
      mail.should have(1).postmark_attachments
      mail.postmark_attachments.first["Name"] == 'a.csv'
      mail.body.should match(/BADSTYLE/)
    end
  end
  describe :outbound_file do
    before :each do
      @cd_length = CustomDefinition.create!(:label=>"Length (cm)",:data_type=>"string",:module_type=>"Product")
      @cd_width = CustomDefinition.create!(:label=>"Width (cm)",:data_type=>"string",:module_type=>"Product")
      @cd_height = CustomDefinition.create!(:label=>"Height (cm)",:data_type=>"string",:module_type=>"Product")
      @t = Factory(:tariff_record,:hts_1=>"1234567890",:hts_2=>"0123456789",:hts_3=>"98765432")
      ['US','IT','CA','TW'].each {|iso| Factory(:country,:iso_code=>iso)}
      @c = @t.classification
      @p = @c.product
      @p.update_custom_value! @cd_length, "1"
      @p.update_custom_value! @cd_width, "2"
      @p.update_custom_value! @cd_height, "3"
      @h = OpenChain::CustomHandler::PoloMslPlusEnterpriseHandler.new
      @h.stub(:send_file)
    end
    it "should generate file with appropriate values" do
      @tmp = @h.generate_outbound_sync_file Product.where("1=1")
      r = CSV.parse IO.read @tmp.path
      r.should have(2).rows
      row = r[1]
      row[0].should == @p.unique_identifier
      row[1].should == @c.country.iso_code
      row[2].should == '' #MP1
      row[3].should == @t.hts_1.hts_format
      row[4].should == @t.hts_2.hts_format
      row[5].should == @t.hts_3.hts_format
      row[6].should == "1" #length
      row[7].should == "2" #width
      row[8].should == "3" #height
    end
    it "should write headers" do
      @tmp = @h.generate_outbound_sync_file Product.where("1=1")
      r = CSV.parse IO.read @tmp.path
      row = r[0]
      row[0].should == "Style" 
      row[1].should == "Country"
      row[2].should == "MP1 Flag"
      row[3].should == "HTS 1"
      row[4].should == "HTS 2"
      row[5].should == "HTS 3"
      row[6].should == "Length"
      row[7].should == "Width"
      row[8].should == "Height"
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
    it "should not send US, Canada, Italy" do
      ['US','CA','IT'].each do |iso|
        Factory(:tariff_record,:classification=>Factory(:classification,:country=>Country.find_by_iso_code(iso),:product=>@p),:hts_1=>'654321')
      end
      @p.reload
      @p.classifications.count.should == 4
      @tmp = @h.generate_outbound_sync_file [@p]
      r = CSV.parse IO.read @tmp.path
      r.should have(2).rows
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
    end
  end
  describe :send_file do
    it 'should send file' do
      @tmp = Tempfile.new('y')
      fn = 'abc.txt'
      FtpSender.should_receive(:send_file).with("ftp.chain.io","polo","pZZ117",@tmp,{:folder=>'/_test_to_msl',:remote_file_name=>fn})
      OpenChain::CustomHandler::PoloMslPlusEnterpriseHandler.new.send_file(@tmp,fn)
    end
  end
  describe :inbound_file do
    before :each do
      @file_content = IO.read 'spec/support/bin/msl_plus_enterprise_inbound_sample.csv'
      @h = OpenChain::CustomHandler::PoloMslPlusEnterpriseHandler.new
      @style_numbers = ["7352024LTBR","3221691177NY","322169117JAL","443590","4371543380AX"]
      @h.stub(:send_file)
    end
    it "should create custom fields" do
      @tmp = @h.process @file_content
      field_names = ["Board Number","GCC Description","MSL+ HTS Description","MSL+ US Season",
        "MSL+ Item Description","MSL+ Model Description","MSL+ HTS Description 2","MSL+ HTS Description 3",
        "AX Subclass","MSL+ US Brand","MSL+ US Sub Brand","MSL+ US Class","MSL+ Receive Date"]
      field_names.each do |fn| 
        cd = CustomDefinition.find_by_label(fn)
        cd.module_type.should == "Product"
        if fn=="MSL+ Receive Date"
          cd.data_type.should == "date"
        else
          cd.data_type.should == "string"
        end
      end
    end
    it "should write new product" do
      @tmp = @h.process @file_content
      Product.count.should == 5
      Product.all.collect {|p| p.unique_identifier}.should == @style_numbers 
      p = Product.where(:unique_identifier=>"7352024LTBR").includes(:custom_values).first
      p.get_custom_value(CustomDefinition.find_by_label("Board Number")).value.should == "O26SC10"
      p.get_custom_value(CustomDefinition.find_by_label('GCC Description')).value.should =='Men\'s Jacket'
      p.get_custom_value(CustomDefinition.find_by_label('MSL+ HTS Description')).value.should =='100% Real Lambskin Men\'s Jacket'
      p.get_custom_value(CustomDefinition.find_by_label('MSL+ US Season')).value.should =='F12'
      p.get_custom_value(CustomDefinition.find_by_label('MSL+ Item Description')).value.should =='LEATHER BARRACUDA-POLYESTER'
      p.get_custom_value(CustomDefinition.find_by_label('MSL+ Model Description')).value.should =='LEATHER BARRACUDA'
      p.get_custom_value(CustomDefinition.find_by_label('MSL+ HTS Description 2')).value.should =='TESTHTS2'
      p.get_custom_value(CustomDefinition.find_by_label('MSL+ HTS Description 3')).value.should =='TESTHTS3'
      p.get_custom_value(CustomDefinition.find_by_label('AX Subclass')).value.should =='Suede/Leather Outerwear'
      p.get_custom_value(CustomDefinition.find_by_label('MSL+ US Brand')).value.should =='Menswear'
      p.get_custom_value(CustomDefinition.find_by_label('MSL+ US Sub Brand')).value.should =='POLO SPORTSWEAR'
      p.get_custom_value(CustomDefinition.find_by_label('MSL+ US Class')).value.should =='OUTERWEAR'
      p.get_custom_value(CustomDefinition.find_by_label('MSL+ Receive Date')).value.should == Date.today 
    end
    it "should update existing product" do
      cd = CustomDefinition.create!(:label=>"Board Number",:data_type=>"string",:module_type=>"Product")
      cd_rec = CustomDefinition.create!(:label=>"MSL+ Receive Date",:data_type=>"date",:module_type=>"Product")
      p = Product.create!(:unique_identifier=>"7352024LTBR")
      p.update_custom_value! cd, "ABC"
      p.update_custom_value! cd_rec, 1.year.ago
      @tmp = @h.process @file_content
      p = Product.find_by_unique_identifier("7352024LTBR")
      p.get_custom_value(cd).value.should == "O26SC10"
      p.get_custom_value(cd_rec).value.should == Date.today 
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
      @tmp = @h.process @file_content
      tmp_content = CSV.parse IO.read @tmp.path
      tmp_content[1][2].should == "PERROR"
      tmp_content[2][0].should == "3221691177NY" 
    end
    it "should FTP acknowledgement file" do
      @tmp = @h.process @file_content
      @h.should_receive(:send_file).with(@tmp,'abc-ack.csv')
      @h.send_and_delete_ack_file @tmp, 'abc.csv'
      File.exists?(@tmp.path).should be_false
    end
  end
end
