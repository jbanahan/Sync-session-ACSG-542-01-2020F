describe OpenChain::Report::SqlProxyDataReport do

  class FakeReport
    include OpenChain::Report::SqlProxyDataReport

    def self.sql_proxy_query_name a, b
      raise "Mock Me"
    end

    def self.sql_proxy_parameters a, b
      {}
    end

    def get_data_conversions a, b
      {}
    end

    def sql_proxy_query_name
      raise "Mock Me"
    end

    def sql_proxy_parameters a, b
      raise "Mock Me"
    end

    def worksheet_name a, b
      raise "Mock Me"
    end

    def column_headers a, b
      raise "Mock Me"
    end

    def report_filename a, b
      raise "Mock Me"
    end
  end

  subject { FakeReport.new }
  let (:sheet) {
    wb = XlsMaker.create_workbook 'test'
    wb.worksheets[0]
  }

  describe "table_from_sql_proxy_query" do
    it "receives sql proxy results and writes them to a spreadsheet" do
      results = [{'a' => 'A', 'b'=>"B"}]
      column_headers = {'a' => "Aleph", 'b' => "Beit"}

      subject.table_from_sql_proxy_query sheet, results, column_headers

      expect(sheet.row(0)).to eq ["Aleph", "Beit"]
      expect(sheet.row(1)).to eq ["A", "B"]
    end

    it "receives sql proxy results and writes them to a spreadsheet, using conversions" do
      results = [{'a' => 'A', 'b'=>"B"}]
      column_headers = {'a' => "Aleph", 'b' => "Beit"}
      data_conversions = {'a' => lambda {|r, v| v == 'A' ? "א" : v}, 'b' => lambda {|r, v| v == 'B' ? "ב" : v}}

      subject.table_from_sql_proxy_query sheet, results, column_headers, data_conversions

      expect(sheet.row(0)).to eq ["Aleph", "Beit"]
      expect(sheet.row(1)).to eq ["א", "ב"]
    end

    it "handles nil results" do
      column_headers = {'a' => "Aleph", 'b' => "Beit"}
      subject.table_from_sql_proxy_query sheet, nil, column_headers
      expect(sheet.row(0)).to eq ["Aleph", "Beit"]
    end
  end

  describe "alliance_date_conversion" do
    it "returns a lambda that converts YYYYMMDD Strings to Date" do
      c = subject.alliance_date_conversion
      expect(c.call nil, '20140528').to eq Date.new(2014, 5, 28)
    end

    it "returns a lambda that converts YYYYMMDD Numbers to Date" do
      c = subject.alliance_date_conversion
      expect(c.call nil, 20140528).to eq Date.new(2014, 5, 28)

      expect(c.call nil, BigDecimal.new(20140528)).to eq Date.new(2014, 5, 28)
    end

    it "returns a lambda that handles nil" do
      expect(subject.alliance_date_conversion.call(nil, nil)).to be_nil
    end

    it "returns a lambda that handles zero values" do
      expect(subject.alliance_date_conversion.call(nil, 0)).to be_nil
      expect(subject.alliance_date_conversion.call(nil, BigDecimal.new(0))).to be_nil
      expect(subject.alliance_date_conversion.call(nil, "00000000")).to be_nil
    end
  end

  describe "process_results" do

    after :each do
      @tf.close! if @tf && !@tf.closed?
    end

    it "handles results and returns a tempfile containing a spreadsheet" do
      u = User.new
      settings = {'a' => "b"}
      expect(subject).to receive(:worksheet_name).with(u, settings).and_return "Test"
      expect(subject).to receive(:column_headers).with(u, settings).and_return({'a' => "Aleph", 'b' => "Beit"})
      expect(subject).to receive(:report_filename).with(u, settings).and_return "file.xls"

      results = [{'a' => 'A', 'b'=>"B"}]

      @tf = subject.process_results u, results, settings
      expect(@tf.original_filename).to eq "file.xls"
      wb = Spreadsheet.open @tf.path
      sheet = wb.worksheets[0]
      expect(sheet.name).to eq "Test"
      expect(sheet.row(0)).to eq ["Aleph", "Beit"]
      expect(sheet.row(1)).to eq ["A", "B"]
    end

    it "handles results and returns a tempfile containing a spreadsheet, using conversions" do
      u = User.new
      settings = {'a' => "b"}
      expect(subject).to receive(:worksheet_name).with(u, settings).and_return "Test"
      expect(subject).to receive(:column_headers).with(u, settings).and_return({'a' => "Aleph", 'b' => "Beit"})
      expect(subject).to receive(:report_filename).with(u, settings).and_return "file.xls"
      expect(subject).to receive(:get_data_conversions).with(u, settings).and_return({'a' => lambda {|r, v| v == 'A' ? "א" : v}, 'b' => lambda {|r, v| v == 'B' ? "ב" : v}})

      results = [{'a' => 'A', 'b'=>"B"}]

      @tf = subject.process_results u, results, settings
      expect(@tf.original_filename).to eq "file.xls"
      wb = Spreadsheet.open @tf.path
      sheet = wb.worksheets[0]
      expect(sheet.name).to eq "Test"
      expect(sheet.row(0)).to eq ["Aleph", "Beit"]
      expect(sheet.row(1)).to eq ["א", "ב"]
    end
  end

  describe "run_report" do
    it "sets up for call to sql proxy" do
      u = User.new
      c = double("SqlProxyClient")
      settings = {"a" => "b", 'sql_proxy_client' => c, 'report_result_id'=>1}
      expect(subject.class).to receive(:sql_proxy_query_name).with(u, settings).and_return "test"

      expect(c).to receive(:report_query).with("test", {"a"=>"b"}, {'report_result_id'=>1})

      subject.class.run_report u, settings
    end

    it "sets up for call to sql proxy using custom parameters override" do
      u = User.new
      c = double("SqlProxyClient")
      settings = {"a" => "b", 'sql_proxy_client' => c, 'report_result_id'=>1}
      expect(subject.class).to receive(:sql_proxy_query_name).with(u, settings).and_return "test"
      expect(subject.class).to receive(:sql_proxy_parameters).with(u, settings).and_return({"custom"=>"params"})

      expect(c).to receive(:report_query).with("test", {"custom"=>"params"}, {'report_result_id'=>1})

      subject.class.run_report u, settings
    end
  end

  describe "process_alliance_query_details" do
    it "instantiates a new class instance and calls process results" do
      u = User.new
      results = []
      settings = {}

      expect(subject.class).to receive(:new_instance).with(u, results, settings).and_return subject
      expect(subject).to receive(:process_results).with(u, results, settings)

      subject.class.process_sql_proxy_query_details u, results, settings
    end
  end

  describe "decimal_conversion" do
    it "converts string values to decimals rounding to 2 decimals by default" do
      l = subject.decimal_conversion
      expect(l.call(nil, "12.345")).to eq BigDecimal("12.35")
    end

    it "allows for adding missing decimal points back into number string, and to adjust decimal place useage" do
      l = subject.decimal_conversion decimal_offset: 6, decimal_places: 6
      expect(l.call(nil, "1420400")).to eq BigDecimal("1.4204")
    end

    it "handles adding leading zeros to use the correct decimal offset" do
      l = subject.decimal_conversion decimal_offset: 6, decimal_places: 6
      expect(l.call(nil, "1235")).to eq BigDecimal("0.001235")
    end
  end
end
