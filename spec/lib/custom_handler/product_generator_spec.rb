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

  describe "sync" do

    before :each do 
      @p1 = Factory(:product,:name=>'x')
    end
    context :row_count do
      before :each do
        @inst = @base.new
      end
      it "should report rows written" do
        @inst.sync {|r| nil} #don't need to do anything with the rows
        expect(@inst.row_count).to eq(2)
      end
      it "should count exploded rows" do
        def @inst.preprocess_row r, opts={}; [r,r]; end
        @inst.sync {|r| nil} #don't need to do anything with the rows
        expect(@inst.row_count).to eq(3)
      end
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
        expect(r).to eq([{0=>'UID',1=>'NM'},{0=>@p1.unique_identifier,1=>'x'}])
      end
      it "should allow override to create new rows" do
        def @inst.preprocess_row row, opts={}
          [row,row] #double it
        end
        r = []
        @inst.sync do |row|
          r << row
        end
        expect(r).to eq([{0=>'UID',1=>'NM'},{0=>@p1.unique_identifier,1=>'x'},{0=>@p1.unique_identifier,1=>'x'}])
      end

      it "should skip preprocess rows that return nil" do
        def @inst.preprocess_row row, opts={}
          nil
        end

        r = []
        @inst.sync do |row|
          r << row
        end

        expect(r.blank?).to be_truthy
      end

      it "should skip preprocess rows that return blank arrays" do
        def @inst.preprocess_row row, opts={}
          []
        end

        r = []
        @inst.sync do |row|
          r << row
        end

        expect(r.blank?).to be_truthy
      end

      it "notifies preprocess_rows when the final row of the result set is being processed" do
        # Add a second product so we can ensure the first call to preprocess_row receives false as last_row and the second true
        p2 = Factory(:product, name: 'y')

        # don't care about the actual row values for this test, only the last result opt
        expect(@inst).to receive(:preprocess_row).ordered.with(instance_of(Hash), last_result: false, product_id: @p1.id).and_return []
        expect(@inst).to receive(:preprocess_row).ordered.with(instance_of(Hash), last_result: true, product_id: p2.id).and_return []

        @inst.sync {|row| nil}
      end
    end
    context :preprocess_header_row do
      before :each do
        @inst = @base.new
      end

      it "does not transform header row by default" do
        r = []
        @inst.sync do |row|
          r << row
        end
        expect(r.first).to eq({0=>'UID',1=>'NM'})
      end

      it "allows overriding with custom transform" do
        # Strip one of the columns
        def @inst.preprocess_header_row row, opts={}
          [{0=>row[1]}]
        end

        r = []
        @inst.sync do |row|
          r << row
        end
        expect(r.first).to eq({0=>'NM'})
      end

      it "allows skipping the header row" do
        def @inst.preprocess_header_row row, opts={}
          nil
        end

        r = []
        @inst.sync do |row|
          r << row
        end
        expect(r.first).to eq({0=>@p1.unique_identifier,1=>'x'})
      end

      it "allows adding multiple header rows" do
        def @inst.preprocess_header_row row, opts={}
          [{0=>row[1]}, {0=>row[0]}]
        end

        r = []
        @inst.sync do |row|
          r << row
        end
        expect(r.first).to eq({0=>'NM'})
        expect(r.second).to eq({0=>'UID'})
        expect(@inst.row_count).to eq 3
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
          expect(records.size).to eq(1)
          sr = records.first
          expect(sr.sent_at).to be < sr.confirmed_at
        end
        it "should delete existing sync_records" do
          base_rec = @p1.sync_records.create!(:trading_partner=>"SYN")
          @tmp = @inst.sync {|r| nil}
          expect(SyncRecord.find_by_id(base_rec.id)).to be_nil
        end
        it "should not delete sync_records for other trading partners" do
          other_rec = @p1.sync_records.create!(:trading_partner=>"OTHER")
          @tmp = @inst.sync {|r| nil}
          expect(SyncRecord.find_by_id(other_rec.id)).not_to be_nil
        end
      end
      it "should not write sync_records if class doesn't implement sync_code" do
        @tmp = @base.new.sync {|r| nil}
        expect(@p1.sync_records).to be_empty
      end
    end
  end

  describe "sync_csv" do
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
      expect(a[0][0]).to eq("UID")
      expect(a[0][1]).to eq("NM")
      [@p1,@p2].each_with_index do |p,i|
        expect(a[i+1][0]).to eq(p.unique_identifier)
        expect(a[i+1][1]).to eq(p.name)
      end
    end
    it "should create csv without headers" do
      @tmp = @base.new.sync_csv false
      a = CSV.parse IO.read @tmp
      [@p1,@p2].each_with_index do |p,i|
        expect(a[i][0]).to eq(p.unique_identifier)
        expect(a[i][1]).to eq(p.name)
      end
    end
    it "should return nil if no records returned" do
      Product.destroy_all
      @tmp = @base.new.sync_csv
      expect(@tmp).to be_nil
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
      expect(a[0][0]).to eq("A")
      expect(a[1][0]).to eq("B")
      expect(a[2][0]).to eq("C")
    end
  end
  describe "sync_fixed_position" do
    before :each do 
      @t = 0.seconds.ago 
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
      expect(r).to eq("ABC#{@t.strftime('%Y%m%d')}   5\n")
    end
  end
  describe "sync_xls" do
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
        expect(r[0]).to eq(p.unique_identifier)
        expect(r[1]).to eq(p.name)
      end
    end
    it "should return nil if no results" do
      Product.destroy_all
      @tmp = @base.new.sync_xls
      expect(@tmp).to be_nil
    end

  end

  describe "cd_s" do
    it "should generate a subselect with an alias" do
      cd = Factory(:custom_definition, :module_type=>'Product')
      subselect = @base.new.cd_s cd.id
      expect(subselect).to eq("(SELECT IFNULL(#{cd.data_column},\"\") FROM custom_values WHERE customizable_id = products.id AND custom_definition_id = #{cd.id}) as `#{cd.label}`")
    end
    it "should generate a subselect without an alias" do
      cd = Factory(:custom_definition, :module_type=>'Product')
      subselect = @base.new.cd_s cd.id, suppress_alias: true
      expect(subselect).to eq("(SELECT IFNULL(#{cd.data_column},\"\") FROM custom_values WHERE customizable_id = products.id AND custom_definition_id = #{cd.id})")
    end
    it "should gracefully handle missing definitions" do
      subselect = @base.new.cd_s -1
      expect(subselect).to eq("(SELECT \"\") as `Custom -1`")
    end
    it "should gracefully handle missing definitions without an alias" do
      subselect = @base.new.cd_s -1, suppress_alias: true
      expect(subselect).to eq("(SELECT \"\")")
    end
    it "should cache the custom defintion lookup" do
      cd = Factory(:custom_definition, :module_type=>'Product')
      gen = @base.new
      subselect = gen.cd_s cd.id
      cd.delete

      subselect = gen.cd_s cd.id
      expect(subselect).to eq("(SELECT IFNULL(#{cd.data_column},\"\") FROM custom_values WHERE customizable_id = products.id AND custom_definition_id = #{cd.id}) as `#{cd.label}`")
    end

    it "should allow disabling custom definition select" do
      cd = Factory(:custom_definition, :module_type=>'Product')
      subselect = @base.new.cd_s cd.id, suppress_data: true
      expect(subselect).to eq("NULL as `#{cd.label}`")
    end
  end

  describe "write_sync_records" do
    it "replaces old sync records, incorporates values of #autoconfirm and #has_fingerprint into record insertions" do
      inst = @base.new
      allow(inst).to receive(:sync_code).and_return('SYNC_CODE')
      prod_1 = Factory(:product)
      prod_2 = Factory(:product)
      prod_3 = Factory(:product)
      SyncRecord.create!(syncable: prod_1, trading_partner: inst.sync_code, fingerprint: "finger_1_old", created_at: DateTime.now-2.day)
      SyncRecord.create!(syncable: prod_2, trading_partner: inst.sync_code, fingerprint: "finger_2_old", created_at: DateTime.now-2.day)
      SyncRecord.create!(syncable: prod_3, trading_partner: inst.sync_code, fingerprint: "finger_3_old", created_at: DateTime.now-2.day)
      allow(inst).to receive(:trim_fingerprint)
      allow(inst).to receive(:autoconfirm).and_return(true)
      
      inst.write_sync_records({prod_1.id => "finger_1_new", prod_2.id => "finger_2_new"}) #replaces 2 out of 3
      sync_1 = SyncRecord.where(syncable_id: prod_1.id).first
      sync_2 = SyncRecord.where(syncable_id: prod_2.id).first
      sync_3 = SyncRecord.where(syncable_id: prod_3.id).first
      
      expect(sync_1.fingerprint).to eq "finger_1_new"
      expect(sync_1.trading_partner).to eq inst.sync_code
      expect(sync_1.created_at).to be > (DateTime.now - 1.day)
      expect(sync_1.confirmed_at).to_not be_nil
      expect(sync_1.sent_at).to_not be_nil

      expect(sync_2.fingerprint).to eq "finger_2_new"
      expect(sync_2.trading_partner).to eq inst.sync_code
      expect(sync_2.created_at).to be > (DateTime.now - 1.day)
      expect(sync_2.confirmed_at).to_not be_nil
      expect(sync_2.sent_at).to_not be_nil

      expect(sync_3.fingerprint).to eq "finger_3_old"
      expect(sync_3.trading_partner).to eq inst.sync_code
      expect(sync_3.created_at).to be < (DateTime.now - 1.day)
    end
  end
end
