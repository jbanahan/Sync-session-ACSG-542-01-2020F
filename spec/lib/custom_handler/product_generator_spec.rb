require 'spec_helper'

describe OpenChain::CustomHandler::ProductGenerator do
  
  before :each do
    @base = Class.new(OpenChain::CustomHandler::ProductGenerator) do
      def ftp_credentials 
        {:server=>'svr',:username=>'u',:password=>'p',:folder=>'f',:remote_file_name=>'r'}
      end

      def query
        "select id, unique_identifier as 'UID', name as 'NM' from products order by products.id asc"
      end
    end
  end

  describe :sync do

    before :each do 
      @p1 = Factory(:product,:name=>'x')
    end
    context :preprocess_row do
      before :each do
        @inst = @base.new
      end
      it "should default to not doing anything" do
        r = []
        @inst.sync do |row|
          r << row
        end
        r.should == [{0=>'UID',1=>'NM'},{0=>@p1.unique_identifier,1=>'x'}]
      end
      it "should allow override to create new rows" do
        def @inst.preprocess_row row
          [row,row] #double it
        end
        r = []
        @inst.sync do |row|
          r << row
        end
        r.should == [{0=>'UID',1=>'NM'},{0=>@p1.unique_identifier,1=>'x'},{0=>@p1.unique_identifier,1=>'x'}]
      end
    end
    context :sync_records do
      context :implments_sync_code do
        before :each do
          @inst = @base.new
          def @inst.sync_code; "SYN"; end
        end
        it "should write sync_records if class implements sync_code" do
          @tmp = @inst.sync {|r| nil}
          records = @p1.sync_records.where(:trading_partner=>"SYN")
          records.should have(1).sync_record
          sr = records.first
          sr.sent_at.should < sr.confirmed_at
        end
        it "should delete existing sync_records" do
          base_rec = @p1.sync_records.create!(:trading_partner=>"SYN")
          @tmp = @inst.sync {|r| nil}
          SyncRecord.find_by_id(base_rec.id).should be_nil
        end
        it "should not delete sync_records for other trading partners" do
          other_rec = @p1.sync_records.create!(:trading_partner=>"OTHER")
          @tmp = @inst.sync {|r| nil}
          SyncRecord.find_by_id(other_rec.id).should_not be_nil
        end
      end
      it "should not write sync_records if class doesn't implement sync_code" do
        @tmp = @base.new.sync {|r| nil}
        @p1.sync_records.should be_empty
      end
    end
  end

  describe :sync_csv do
    before :each do
      @p1 = Factory(:product,:name=>'x')
      @p2 = Factory(:product,:name=>'y')
    end
    after :each do
      @tmp.unlink if @tmp
    end

    it "should create csv from results" do
      @tmp = @base.new.sync_csv
      a = CSV.parse IO.read @tmp
      a[0][0].should == "UID"
      a[0][1].should == "NM"
      [@p1,@p2].each_with_index do |p,i|
        a[i+1][0].should == p.unique_identifier
        a[i+1][1].should == p.name
      end
    end
    it "should create csv without headers" do
      @tmp = @base.new.sync_csv false
      a = CSV.parse IO.read @tmp
      [@p1,@p2].each_with_index do |p,i|
        a[i][0].should == p.unique_identifier
        a[i][1].should == p.name
      end
    end
    it "should return nil if no records returned" do
      Product.destroy_all
      @tmp = @base.new.sync_csv
      @tmp.should be_nil
    end

    it "should call before_csv_write callback" do
    @base = Class.new(OpenChain::CustomHandler::ProductGenerator) do
      def initialize
        @vals = ["A","B","C"]
      end
      def ftp_credentials 
        {:server=>'svr',:username=>'u',:password=>'p',:folder=>'f',:remote_file_name=>'r'}
      end

      def query
        "select id, unique_identifier as 'UID', name as 'NM' from products order by products.id asc"
      end
      def before_csv_write cursor, vals
        [@vals[cursor]]
      end
    end
#      @base.should_receive(:before_csv_write).with(0,["UID","NM"]).ordered.and_return("A")
#      @base.should_receive(:before_csv_write).with(1,[@p1.unique_identifier,@p1.name]).ordered.and_return("B")
#      @base.should_receive(:before_csv_write).with(2,[@p2.unique_identifier,@p2.name]).ordered.and_return("C")
      @tmp = @base.new.sync_csv
      a = CSV.parse IO.read @tmp
      a[0][0].should == "A"
      a[1][0].should == "B"
      a[2][0].should == "C"
    end
  end
  describe :sync_fixed_position do
    before :each do 
      @t = Time.now
      @p1 = Factory(:product,:name=>'ABCDEFG',:created_at=>@t)
      @b = @base.new
      def @b.query
        'select id, name, created_at, 5 from products'
      end
    end
    after :each do 
      @tmp.unlink if @tmp
    end
    it "should create fixed position file from results" do
      def @b.fixed_position_map
        [{:len=>3},{:len=>8,:to_s=>lambda {|o| o.strftime("%Y%m%d")}},{:len=>4}]
      end
      @tmp = @b.sync_fixed_position
      r = IO.read @tmp
      r.should == "ABC#{@t.strftime('%Y%m%d')}   5\n"
    end
  end
  describe :sync_xls do
    before :each do 
      @p1 = Factory(:product,:name=>'x')
    end
    after :each do
      @tmp.unlink if @tmp
    end
    it "should create workbook from results" do
      p2 = Factory(:product,:name=>'y')
      @tmp = @base.new.sync_xls
      sheet = Spreadsheet.open(@tmp).worksheet(0)
      [@p1,p2].each_with_index do |p,i|
        r = sheet.row(i+1)
        r[0].should == p.unique_identifier
        r[1].should == p.name
      end
    end
    it "should return nil if no results" do
      Product.destroy_all
      @tmp = @base.new.sync_xls
      @tmp.should be_nil
    end

  end
  describe :ftp_file do
    before :each do
      @t = mock('tmpfile')
      @t.stub(:path).and_return('/x.badfile')
    end
    it "should ftp_file" do
      File.stub(:exists?).and_return true
      @t.should_receive(:unlink)
      FtpSender.should_receive(:send_file).with('svr','u','p',@t,{:folder=>'f',:remote_file_name=>'r'})
      @base.new.ftp_file @t
    end
    it 'should not unlink if false is passed' do
      File.stub(:exists?).and_return true
      @t.should_not_receive(:unlink)
      FtpSender.should_receive(:send_file).with('svr','u','p',@t,{:folder=>'f',:remote_file_name=>'r'})
      @base.new.ftp_file @t, false
    end
    it "should return false if file is nil" do
      File.stub(:exists?).and_return true
      FtpSender.should_not_receive(:send_file)
      @base.new.ftp_file(nil).should be_false
    end
    it "should return false if file does not exist" do
      FtpSender.should_not_receive(:send_file)
      @base.new.ftp_file(@t).should be_false
    end
  end

  describe :cd_s do
    it "should generate a subselect with an alias" do
      cd = Factory(:custom_definition, :module_type=>'Product')
      subselect = @base.new.cd_s cd.id
      subselect.should == "(SELECT IFNULL(#{cd.data_column},\"\") FROM custom_values WHERE customizable_id = products.id AND custom_definition_id = #{cd.id}) as `#{cd.label}`"
    end
    it "should generate a subselect without an alias" do
      cd = Factory(:custom_definition, :module_type=>'Product')
      subselect = @base.new.cd_s cd.id, true
      subselect.should == "(SELECT IFNULL(#{cd.data_column},\"\") FROM custom_values WHERE customizable_id = products.id AND custom_definition_id = #{cd.id})"
    end
    it "should gracefully handle missing definitions" do
      subselect = @base.new.cd_s -1
      subselect.should == "(SELECT \"\") as `Custom -1`"
    end
    it "should gracefully handle missing definitions without an alias" do
      subselect = @base.new.cd_s -1, true
      subselect.should == "(SELECT \"\")"
    end
    it "should cache the custom defintion lookup" do
      cd = Factory(:custom_definition, :module_type=>'Product')
      gen = @base.new
      subselect = gen.cd_s cd.id
      cd.delete

      subselect = gen.cd_s cd.id
      subselect.should == "(SELECT IFNULL(#{cd.data_column},\"\") FROM custom_values WHERE customizable_id = products.id AND custom_definition_id = #{cd.id}) as `#{cd.label}`"
    end
  end
end
