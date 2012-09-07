require 'spec_helper'

describe OpenChain::CustomHandler::PoloMslPlusEnterpriseHandler do
  before :each do
    @file_content = IO.read 'spec/support/bin/msl_plus_enterprise_inbound_sample.csv'
    @h = OpenChain::CustomHandler::PoloMslPlusEnterpriseHandler.new
    @style_numbers = ["7352024LTBR","3221691177NY","322169117JAL","443590","4371543380AX"]
    FtpSender.stub(:send_file) #just incase
  end
  after :each do
    @tmp.unlink if @tmp
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
    FtpSender.should_receive(:send_file).with("ftp.chain.io","polo","pZZ117",@tmp,{:folder=>'/_test_to_msl',:remote_file_name=>'abc-ack.csv'}).and_return(nil)
    @h.send_and_delete_ack_file @tmp, 'abc.csv'
    File.exists?(@tmp.path).should be_false
  end
end
