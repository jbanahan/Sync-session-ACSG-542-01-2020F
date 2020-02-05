describe OpenChain::Report::ReportHelper do

  subject {
    Class.new do
      include OpenChain::Report::ReportHelper
    end.new
  }

  describe "table_from_query" do
    subject {
      Class.new do
        include OpenChain::Report::ReportHelper
        attr_accessor :sheet

        def run query, conversions = {}, opts = {}
          wb = Spreadsheet::Workbook.new
          @sheet = wb.create_worksheet :name=>'x'
          table_from_query @sheet, query, conversions, opts
        end
      end.new
    }

    it "runs a query, adds headers to sheet, passing control to write result sheet" do
      e = Factory(:entry, entry_number: "123")
      q = "SELECT entry_number as 'EN', id as 'IDENT' FROM entries order by entry_number ASC"
      expect(subject.run q).to eq 1

      expect(subject.sheet.rows.length).to eq 2
      expect(subject.sheet.row(0)).to eq ["EN", "IDENT"]
      expect(subject.sheet.row(1)).to eq ["123", e.id]
    end

    it "shifts off the leftmost X columns if query column offset is used" do
      e = Factory(:entry, entry_number: "123")
      q = "SELECT 'test' as 'TEST', entry_number as 'EN', id as 'IDENT' FROM entries order by entry_number ASC"
      subject.run q, {}, query_column_offset: 1
      sheet = subject.sheet
      expect(sheet.rows.length).to eq 2
      expect(sheet.row(0)).to eq ["EN", "IDENT"]
      expect(sheet.row(1)).to eq ["123", e.id]
    end

    it "uses conversions associated with column aliases, even if columns are not displayed on report" do
      Factory(:entry, broker_reference: "123")
      query = "SELECT e.id 'ID', e.broker_reference 'REF' FROM entries e"
      id = nil
      # By setting id value in the conversion lambda on a column that's not on the report, we ensure that conversions
      # are definitely still being run over that column
      subject.run query, {'ID' => lambda { |row, value| id = "Run"}}, query_column_offset: 1
      expect(id).to eq "Run"
    end
  end

  # mostly tested in table_from_query
  describe "table_from_query_result"  do
    before :each do
      q = "SELECT entry_number as 'EN', id as 'IDENT' FROM entries order by entry_number ASC"
      @result_set = ActiveRecord::Base.connection.execute q
    end

    it "extracts columns headers from result_set by default" do
      wb, sheet = XlsMaker.create_workbook_and_sheet "Test"
      expect(XlsMaker).to receive(:add_header_row).with(sheet, 0, ['EN', 'IDENT'])
      subject.table_from_query_result sheet, @result_set
    end

    it "extracts columns from opts if :column_names is used" do
      wb, sheet = XlsMaker.create_workbook_and_sheet "Test"
      expect(XlsMaker).to receive(:add_header_row).with(sheet, 0, ['Nigel', 'David'])
      subject.table_from_query_result sheet, @result_set, {}, {column_names: ['Nigel', 'David']}
    end

    it "uses header_row opt if given as row number to write header" do
      wb, sheet = XlsMaker.create_workbook_and_sheet "Test"
      opts = {column_names: ['Nigel', 'David'], header_row: 5}
      expect(XlsMaker).to receive(:add_header_row).with(sheet, 5, ['Nigel', 'David'])
      expect(subject).to receive(:write_result_set_to_sheet).with(@result_set, sheet, ['Nigel', 'David'], 6, {}, opts)
      subject.table_from_query_result sheet, @result_set, {}, opts
    end
  end

  describe "write_result_set_to_sheet" do

    before :each do
      @wb = XlsMaker.create_workbook 'test'
      @sheet = @wb.worksheets[0]
    end

    it "should write results to the given sheet" do
      e1 = Factory(:entry,:entry_number=>'12345')
      e2 = Factory(:entry,:entry_number=>'65432')
      results = ActiveRecord::Base.connection.execute "SELECT entry_number as 'EN', id as 'IDENT' FROM entries order by entry_number ASC"
      # Start at row 5 just to make sure the return value is actually giving us the # of rows written and not the ending line number
      expect(subject.write_result_set_to_sheet results, @sheet, ["EN", "IDENT"], 5).to eq 2

      expect(@sheet.row(5)).to eq(['12345',e1.id])
      expect(@sheet.row(6)).to eq(['65432',e2.id])
    end

    it "should handle timezone conversion for datetime columns" do
      release_date = 0.seconds.ago
      e1 = Factory(:entry,:entry_number=>'12345', :release_date => release_date)
      results = ActiveRecord::Base.connection.execute "SELECT release_date 'REL1', date(release_date) as 'Rel2' FROM entries order by entry_number ASC"
      Time.use_zone("Hawaii") do
        subject.write_result_set_to_sheet results, @sheet, ["EN", "IDENT"], 0
      end

      expect(@sheet.row(0)[0].to_s).to eq(release_date.in_time_zone("Hawaii").to_s)
      expect(@sheet.row(0)[1].to_s).to eq(release_date.strftime("%Y-%m-%d"))
    end

    it "should convert nil to blank string in excel output" do
      subject.write_result_set_to_sheet [[nil]], @sheet, ["EN"], 0
      expect(@sheet.row(0)).to eq([''])
    end

    it "should use conversion lambdas to format output" do
      conversions = {}
      conversions['Col1'] = lambda {|row, val|
        expect(row).to eq(['A', 'B', 'C'])
        expect(val).to eq("A")
        "Col1"
      }
      conversions[1] = lambda{|row, val|
        expect(row).to eq(['A', 'B', 'C'])
        expect(val).to eq("B")
        "Col2"
      }
      conversions[:col_3] = lambda{|row, val|
        expect(row).to eq(['A', 'B', 'C'])
        expect(val).to eq("C")
        "Col3"
      }
      # Add a lambda by name and symbol for the 3rd column, proves name/symbol takes precedence
      conversions[2] = lambda{|row, val|
        raise "Shouldn't use this conversion."
      }

      subject.write_result_set_to_sheet [['A', 'B', 'C']], @sheet, ['Col1', 'Whatever', 'col_3'], 0, conversions
      expect(@sheet.row(0)).to eq(['Col1', 'Col2', 'Col3'])
    end

    it "offsets output columns if instructed" do
      subject.write_result_set_to_sheet [['A', 'B', 'C']], @sheet, ['Col1', 'Col2', 'Col3'], 0, {}, query_column_offset: 1
      expect(@sheet.row(0)).to eq(['B', 'C'])
    end

    it "sets conversions back into the result set if instructed" do
      conversions = {}
      conversions['Col1'] = lambda {|row, val|
        expect(row).to eq ['A', 'B', 'C']
        "Col1"
      }

      conversions['Col2'] = lambda {|row, val|
        expect(row).to eq ['Col1', 'B', 'C']
        "Col2"
      }

      conversions['Col3'] = lambda {|row, val|
        expect(row).to eq ['Col1', 'Col2', 'C']
        "Col3"
      }

      subject.write_result_set_to_sheet [['A', 'B', 'C']], @sheet, ['Col1', 'Col2', 'Col3'], 0, conversions, translations_modify_result_set: true
      expect(@sheet.row(0)).to eq(['Col1', 'Col2', 'Col3'])
    end

    it "executes conversions even on skipped columns" do
      conversions = {}
      called = false
      conversions['Col1'] = lambda {|row, val|
        called = true
        expect(row).to eq ['A', 'B', 'C']
        "Col1"
      }

      conversions['Col2'] = lambda {|row, val|
        called = true
        expect(row).to eq ['Col1', 'B', 'C']
        "Col2"
      }

      subject.write_result_set_to_sheet [['A', 'B', 'C']], @sheet, ['Col1', 'Col2', 'Col3'], 0, conversions, translations_modify_result_set: true, query_column_offset: 1
      expect(@sheet.row(0)).to eq(['Col2', 'C'])
    end
  end

  context "datetime_translation_lambda" do
    it "should create a lambda that will translate a datetime value into the specified timezone" do
      conversion = subject.datetime_translation_lambda "Hawaii", false

      now = Time.zone.now.in_time_zone "UTC"

      translated = conversion.call nil, now
      # Make sure the translated value is using the specified time zone (by comparing offset values)
      expect(translated.utc_offset).to eq(ActiveSupport::TimeZone["Hawaii"].utc_offset)
      expect(translated.in_time_zone("UTC")).to eq(now)
    end

    it "should return a date if specified" do
      conversion = subject.datetime_translation_lambda "Hawaii", true

      # Use a time we know is going to be one date in UTC and a day earlier in HST.
      now = ActiveSupport::TimeZone["UTC"].parse "2013-01-01 01:00:00"

      translated = conversion.call nil, now
      expect(translated.is_a?(Date)).to be_truthy
      expect(translated.to_s).to eq("2012-12-31")
    end

    it "should handle nil times" do
      conversion = subject.datetime_translation_lambda "Hawaii", false
      expect(conversion.call(nil, nil)).to be_nil
    end
  end

  describe "transport_mode_us_ca_translation_lambda" do
    it "creates a lambda that translates an integer value into its corresponding transport mode descriptor" do
      conversion = subject.transport_mode_us_ca_translation_lambda
      translated = conversion.call nil, 21
      expect(translated).to eq "RAIL"
    end
  end

  describe "weblink_translation_lambda" do
    it "creates a lambda capable of transating an Id value to a URL" do
      ms = double("MasterSetup")
      allow(ms).to receive(:request_host).and_return "localhost"
      allow(MasterSetup).to receive(:get).and_return ms
      l = subject.weblink_translation_lambda CoreModule::PRODUCT
      expect(l.call(nil, 1)).to eq Spreadsheet::Link.new(Product.excel_url(1), "Web View")
    end
  end

  describe "csv_translation_lambda" do
    it "csv's a string" do
      l = subject.csv_translation_lambda
      expect(l.call(nil, "A\nB\n C")).to eq "A, B, C"
    end
    it "uses given parameters to split / joining" do
      l = subject.csv_translation_lambda "\n", ","
      expect(l.call(nil, "A,B,C")).to eq "A\nB\nC"
    end
    it "handles nil / blank values" do
      l = subject.csv_translation_lambda
      expect(l.call(nil, nil)).to eq nil
      expect(l.call(nil, "   ")).to eq "   "
    end
  end

  context "sanitize_date_string" do
    it "should return a date string" do
      s = subject.sanitize_date_string "20130101"
      expect(s).to eq("2013-01-01")
    end

    it "should error on invalid strings" do
      expect{subject.sanitize_date_string "notadate"}.to raise_error(/date/)
    end

    it "should convert date to UTC date time string" do
      s = subject.sanitize_date_string "20130101", "Hawaii"
      expect(s).to eq("2013-01-01 10:00:00")
    end

    it "should accept a date object" do
      s = subject.sanitize_date_string Date.new(2013,1,1), "Hawaii"
      expect(s).to eq("2013-01-01 10:00:00")
    end
  end

  describe "workbook_to_tempfile" do

    before :each do
      @wb = XlsMaker.create_workbook "Name", ["Header"]
    end

    it "writes a workbook to a tempfile and yields the tempfile" do
      workbook = nil
      path = nil
      name = nil
      tempfile = nil
      subject.workbook_to_tempfile(@wb, "prefix", file_name: "test.xls") do |tf|
        workbook = Spreadsheet.open tf
        name = tf.original_filename
        tempfile = tf
      end

      expect(workbook.worksheet(0).row(0)).to eq ["Header"]
      expect(tempfile.closed?).to be_truthy
      expect(name).to eq "test.xls"
    end

    it "writes workbook to tempfile returning tempfile" do
      tf = nil
      begin
        tf = subject.workbook_to_tempfile(@wb, "prefix", file_name: "test.xls")
        expect(tf.original_filename).to eq "test.xls"
        workbook = Spreadsheet.open tf
        expect(workbook.worksheet(0).row(0)).to eq ["Header"]
      ensure
        tf.close! unless tf.closed?
      end
    end
  end

  describe "RowWrapper" do
    it "correctly initializes, reads, assigns, unwraps" do
      r = described_class::RowWrapper.new ["good morning", "good evening"], {foo: 0, bar: 1}
      
      expect(r.field_map).to eq({foo: 0, bar: 1})
      expect(r[:bar]).to eq "good evening"
      
      r[:bar] = "good night"
      
      expect(r[:bar]).to eq "good night"
      expect(r.to_a).to eq ["good morning", "good night"]
    end
  end

end
