describe OpenChain::CustomHandler::ProductGenerator do

  class FakeProductGenerator < OpenChain::CustomHandler::ProductGenerator
    def ftp_credentials 
      {:server=>'svr',:username=>'u',:password=>'p',:folder=>'f',:remote_file_name=>'r'}
    end

    def query
      "select id, unique_identifier as 'UID', name as 'NM' from products order by products.id asc"
    end
  end

  subject { FakeProductGenerator.new }

  describe "sync" do

    before :each do 
      @p1 = Factory(:product,:name=>'x')
    end

    it "resets synced product ids" do
      # Because the subject doesn't implement sync_code by default, the synced product ids are not recorded during
      # the sync call.  Really, this test is here is just to check that reset is called every time sync is called.
      subject.reset_synced_product_ids
      subject.add_synced_product_ids [1, 2, 3]

      subject.sync { |r| nil }

      expect(subject.synced_product_ids).to eq []
    end

    context "row_count" do
      
      it "should report rows written" do
        subject.sync {|r| nil} #don't need to do anything with the rows
        expect(subject.row_count).to eq(2)
      end
      it "should count exploded rows" do
        s = subject

        def s.preprocess_row r, opts={}; [r,r]; end
        s.sync {|r| nil} #don't need to do anything with the rows
        expect(subject.row_count).to eq(3)
      end
    end
    context "preprocess_row" do
      
      it "should default to not doing anything" do
        r = []
        subject.sync do |row|
          r << row
        end
        expect(r).to eq([{0=>'UID',1=>'NM'},{0=>@p1.unique_identifier,1=>'x'}])
      end
      it "should allow override to create new rows" do
        s = subject
        def s.preprocess_row row, opts={}
          [row,row] #double it
        end
        r = []
        s.sync do |row|
          r << row
        end
        expect(r).to eq([{0=>'UID',1=>'NM'},{0=>@p1.unique_identifier,1=>'x'},{0=>@p1.unique_identifier,1=>'x'}])
      end

      it "should skip preprocess rows that return nil" do
        def subject.preprocess_row row, opts={}
          nil
        end

        r = []
        subject.sync do |row|
          r << row
        end

        expect(r.blank?).to be_truthy
      end

      it "should skip preprocess rows that return blank arrays" do
        def subject.preprocess_row row, opts={}
          []
        end

        r = []
        subject.sync do |row|
          r << row
        end

        expect(r.blank?).to be_truthy
      end

      it "notifies preprocess_rows when the final row of the result set is being processed" do
        # Add a second product so we can ensure the first call to preprocess_row receives false as last_row and the second true
        p2 = Factory(:product, name: 'y')

        # don't care about the actual row values for this test, only the last result opt
        expect(subject).to receive(:preprocess_row).ordered.with(instance_of(Hash), last_result: false, product_id: @p1.id).and_return []
        expect(subject).to receive(:preprocess_row).ordered.with(instance_of(Hash), last_result: true, product_id: p2.id).and_return []

        subject.sync {|row| nil}
      end

      it "handles cases when preprocess row throws :mark_synced and syncs the record that was being processed" do
        def subject.preprocess_row row, opts={}
          throw :mark_synced
        end

        def subject.sync_code 
          "code"
        end

        subject.sync {|row| nil}
        @p1.reload
        expect(@p1.sync_records.length).to eq 1
      end

    end
    context "preprocess_header_row" do
      it "does not transform header row by default" do
        r = []
        subject.sync do |row|
          r << row
        end
        expect(r.first).to eq({0=>'UID',1=>'NM'})
      end

      it "allows overriding with custom transform" do
        # Strip one of the columns
        def subject.preprocess_header_row row, opts={}
          [{0=>row[1]}]
        end

        r = []
        subject.sync do |row|
          r << row
        end
        expect(r.first).to eq({0=>'NM'})
      end

      it "allows skipping the header row" do
        def subject.preprocess_header_row row, opts={}
          nil
        end

        r = []
        subject.sync do |row|
          r << row
        end
        expect(r.first).to eq({0=>@p1.unique_identifier,1=>'x'})
      end

      it "allows adding multiple header rows" do
        def subject.preprocess_header_row row, opts={}
          [{0=>row[1]}, {0=>row[0]}]
        end

        r = []
        subject.sync do |row|
          r << row
        end
        expect(r.first).to eq({0=>'NM'})
        expect(r.second).to eq({0=>'UID'})
        expect(subject.row_count).to eq 3
      end

      it "does not yield the header row if instructed not to" do
        r = []
        subject.sync(include_headers: false) do |row|
          r << row
        end
        expect(r.length).to eq 1
        # Only the data row should have been yielded..not the header one
        expect(r.first).to eq ({0=>@p1.unique_identifier, 1=>@p1.name})
      end
    end
    
    context "sync_records" do
      context "implments_sync_code" do
        before :each do
          s = subject
          def s.sync_code; "SYN"; end
        end

        it "should write sync_records if class implements sync_code" do
          @tmp = subject.sync {|r| nil}
          records = @p1.sync_records.where(:trading_partner=>"SYN")
          expect(records.size).to eq(1)
          sr = records.first
          expect(sr.sent_at).to be < sr.confirmed_at
        end
        it "should delete existing sync_records" do
          base_rec = @p1.sync_records.create!(:trading_partner=>"SYN")
          @tmp = subject.sync {|r| nil}
          expect(SyncRecord.find_by_id(base_rec.id)).to be_nil
        end
        it "should not delete sync_records for other trading partners" do
          other_rec = @p1.sync_records.create!(:trading_partner=>"OTHER")
          @tmp = subject.sync {|r| nil}
          expect(SyncRecord.find_by_id(other_rec.id)).not_to be_nil
        end
      end
      it "should not write sync_records if class doesn't implement sync_code" do
        @tmp = subject.sync {|r| nil}
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
      @tmp = subject.sync_csv
      a = CSV.parse IO.read @tmp
      expect(a[0][0]).to eq("UID")
      expect(a[0][1]).to eq("NM")
      [@p1,@p2].each_with_index do |p,i|
        expect(a[i+1][0]).to eq(p.unique_identifier)
        expect(a[i+1][1]).to eq(p.name)
      end
    end
    it "should create csv without headers" do
      @tmp = subject.sync_csv include_headers: false
      a = CSV.parse IO.read @tmp
      [@p1,@p2].each_with_index do |p,i|
        expect(a[i][0]).to eq(p.unique_identifier)
        expect(a[i][1]).to eq(p.name)
      end
    end
    it "should return nil if no records returned" do
      Product.destroy_all
      @tmp = subject.sync_csv
      expect(@tmp).to be_nil
    end

    it "should call before_csv_write callback" do
      allow(subject).to receive(:before_csv_write) do |cursor, value|
        Array.wrap(["A", "B", "C"][cursor])
      end

      @tmp = subject.sync_csv
      a = CSV.parse IO.read @tmp
      expect(a[0][0]).to eq("A")
      expect(a[1][0]).to eq("B")
      expect(a[2][0]).to eq("C")
    end

    it "does not convert nil values to strings if instructed" do
      allow(subject).to receive(:before_csv_write).and_return [nil]

      @tmp = subject.sync_csv use_raw_values: true
      a = CSV.parse IO.read @tmp
      expect(a[0][0]).to be_nil
    end
  end

  describe "sync_fixed_position" do
    before :each do 
      @t = 0.seconds.ago 
      @p1 = Factory(:product,:name=>'ABCDEFG',:created_at=>@t)
      @b = subject
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
      @tmp = subject.sync_xls
      sheet = Spreadsheet.open(@tmp).worksheet(0)
      [@p1,p2].each_with_index do |p,i|
        r = sheet.row(i+1)
        expect(r[0]).to eq(p.unique_identifier)
        expect(r[1]).to eq(p.name)
      end
    end
    it "should return nil if no results" do
      Product.destroy_all
      @tmp = subject.sync_xls
      expect(@tmp).to be_nil
    end

  end

  describe "cd_s" do
    it "should generate a subselect with an alias" do
      cd = Factory(:custom_definition, :module_type=>'Product')
      subselect = subject.cd_s cd.id
      expect(subselect).to eq("(SELECT IFNULL(#{cd.data_column},\"\") FROM custom_values WHERE customizable_id = products.id AND custom_definition_id = #{cd.id}) as `#{cd.label}`")
    end
    it "should generate a subselect without an alias" do
      cd = Factory(:custom_definition, :module_type=>'Product')
      subselect = subject.cd_s cd.id, suppress_alias: true
      expect(subselect).to eq("(SELECT IFNULL(#{cd.data_column},\"\") FROM custom_values WHERE customizable_id = products.id AND custom_definition_id = #{cd.id})")
    end
    it "should gracefully handle missing definitions" do
      subselect = subject.cd_s -1
      expect(subselect).to eq("(SELECT \"\") as `Custom -1`")
    end
    it "should gracefully handle missing definitions without an alias" do
      subselect = subject.cd_s -1, suppress_alias: true
      expect(subselect).to eq("(SELECT \"\")")
    end
    it "should cache the custom defintion lookup" do
      cd = Factory(:custom_definition, :module_type=>'Product')
      gen = subject
      subselect = gen.cd_s cd.id
      cd.delete

      subselect = gen.cd_s cd.id
      expect(subselect).to eq("(SELECT IFNULL(#{cd.data_column},\"\") FROM custom_values WHERE customizable_id = products.id AND custom_definition_id = #{cd.id}) as `#{cd.label}`")
    end

    it "should allow disabling custom definition select" do
      cd = Factory(:custom_definition, :module_type=>'Product')
      subselect = subject.cd_s cd.id, suppress_data: true
      expect(subselect).to eq("NULL as `#{cd.label}`")
    end

    it "receives a custom definition and uses that instead of an id value" do
      cd = Factory(:custom_definition, :module_type=>'Product')
      subselect = subject.cd_s cd
      expect(subselect).to eq "(SELECT IFNULL(#{cd.data_column},\"\") FROM custom_values WHERE customizable_id = products.id AND custom_definition_id = #{cd.id}) as `#{cd.label}`"
    end

    it "allows passing alternate alias" do
      cd = Factory(:custom_definition, :module_type=>'Product')
      subselect = subject.cd_s cd, query_alias: "Testing"
      expect(subselect).to eq "(SELECT IFNULL(#{cd.data_column},\"\") FROM custom_values WHERE customizable_id = products.id AND custom_definition_id = #{cd.id}) as `Testing`"
    end
  end

  describe "write_sync_records" do
    it "replaces old sync records, incorporates values of #autoconfirm and #has_fingerprint into record insertions" do
      inst = subject
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
      
      expect(sync_1).not_to be_nil
      expect(sync_1.fingerprint).to eq "finger_1_new"
      expect(sync_1.trading_partner).to eq inst.sync_code
      expect(sync_1.created_at).to be > (DateTime.now - 1.day)
      expect(sync_1.confirmed_at).to_not be_nil
      expect(sync_1.sent_at).to_not be_nil

      expect(sync_2).not_to be_nil
      expect(sync_2.fingerprint).to eq "finger_2_new"
      expect(sync_2.trading_partner).to eq inst.sync_code
      expect(sync_2.created_at).to be > (DateTime.now - 1.day)
      expect(sync_2.confirmed_at).to_not be_nil
      expect(sync_2.sent_at).to_not be_nil

      expect(sync_3).not_to be_nil
      expect(sync_3.fingerprint).to eq "finger_3_old"
      expect(sync_3.trading_partner).to eq inst.sync_code
      expect(sync_3.created_at).to be < (DateTime.now - 1.day)

      # The system should be recording which product ids its been syncing too
      expect(subject.synced_product_ids.to_a).to eq [prod_1.id, prod_2.id]
    end
  end

  describe "ftp_file" do
    let (:ftp_session) { FtpSession.create! }
    let (:file) { Tempfile.open(["file", ".txt"])}

    after :each do 
      file.close! unless file.nil? || file.closed?
    end

    it "calls super ftp_file implementation and passes the yielded session to sync products method" do 
      expect(FtpSender).to receive(:send_file).and_return ftp_session
      expect(subject).to receive(:set_ftp_session_for_synced_products).with ftp_session
      subject.ftp_file file
    end
  end

  describe "set_ftp_session_for_synced_products" do
    let (:product) { 
      p = Factory(:product) 
      p.sync_records.create! trading_partner: "TEST"
      p
    }
    let (:ftp_session) { FtpSession.create! }

    it "updates recorded sync records with ftp session id" do
      subject.add_synced_product_ids [product.id]

      s = subject
      def s.sync_code
        "TEST"
      end

      subject.set_ftp_session_for_synced_products ftp_session
      product.reload
      r = product.sync_records.first
      expect(r.ftp_session).to eq ftp_session
    end

  end

  describe "sync_xml" do
    let (:header) { {1 => "Col1", 0 => "Col0", 2=>"Col2", 3 => "Col3", 4 => "Col4", 5 => "Col5", 6 => "Col6"} }
    let (:row) { {1 => "Val1", 0 => true, 2 => Time.zone.now, 3 => Time.zone.now.to_date, 4 => BigDecimal("1.25"), 5 => "", 6 => nil} }

    after :each do
      @file.close! if @file && !@file.closed?
    end

    it "writes XML file" do
      expect(subject).to receive(:sync).and_yield(header).and_yield(row)
      @file = subject.sync_xml

      expect(@file).not_to be_nil
      xml = REXML::Document.new(@file.read).root
      expect(xml.name).to eq "Products"
      expect(xml.text "Product/Col0").to eq "true"
      expect(xml.text "Product/Col1").to eq "Val1"
      expect(xml.text "Product/Col2").to eq row[2].strftime("%Y-%m-%d %H:%M")
      expect(xml.text "Product/Col3").to eq row[3].strftime("%Y-%m-%d")
      expect(xml.text "Product/Col4").to eq "1.25"
      # Blank strings evaluate to <Col5/>, which is then read back as nil
      expect(xml.text "Product/Col5").to be_nil
      # Col6 shouldn't be added because its value was nil
      expect(REXML::XPath.each(xml, "Product/Col6").size).to eq 0
    end

    it "calls write_row_to_xml to add elements to XML if implemented" do
      root_element, cursor_val, row_val = nil
      allow(subject).to receive(:write_row_to_xml) do |root, cursor, row|
        row_val = row
        cursor_val = cursor

        t = root.add_element("Test")
        t.text = "Testing"
      end

      expect(subject).to receive(:sync).and_yield(header).and_yield(row)
      @file = subject.sync_xml

      expect(@file).not_to be_nil
      xml = REXML::Document.new(@file.read).root
      expect(xml.name).to eq "Products"
      expect(xml.text "Test").to eq "Testing"

      expect(row_val).to eq [row[0], row[1], row[2], row[3], row[4], row[5], row[6]]
      expect(cursor_val).to eq 0
    end

    it "calls before_xml_write if implemented before writing data to xml" do
      cursor_val, vals = nil
      allow(subject).to receive(:before_xml_write) do |cursor, values|
        cursor_val = cursor
        vals = values

        (0..6).to_a
      end

      expect(subject).to receive(:sync).and_yield(header).and_yield(row)
      @file = subject.sync_xml

      expect(@file).not_to be_nil
      xml = REXML::Document.new(@file.read).root
      expect(xml.name).to eq "Products"
      expect(xml.text "Product/Col0").to eq "0"
      expect(xml.text "Product/Col1").to eq "1"
      expect(xml.text "Product/Col2").to eq "2"
      expect(xml.text "Product/Col3").to eq "3"
      expect(xml.text "Product/Col4").to eq "4"
      expect(xml.text "Product/Col5").to eq "5"
      expect(xml.text "Product/Col6").to eq "6"

      # Make sure the vals passed to the method is the array'ization of the row map yield by the sync method
      expect(vals).to eq row.keys.sort.map {|k| row[k]}
    end

    it "allows for overriding root element name" do
      allow(subject).to receive(:default_root_element_name).and_return "ROOT_ELEMENT"

      expect(subject).to receive(:sync).and_yield(header).and_yield(row)
      @file = subject.sync_xml

      expect(@file).not_to be_nil
      xml = REXML::Document.new(@file.read).root
      expect(xml.name).to eq "ROOT_ELEMENT"
    end

  end

  describe "execute_query" do
    it "uses distrbute_reads" do
      expect(subject).to receive(:distribute_reads).and_yield
      result = subject.send(:execute_query, "SELECT now()")
      expect(result.first[0]).to be_within(1.minute).of(Time.zone.now)
    end
  end
end
