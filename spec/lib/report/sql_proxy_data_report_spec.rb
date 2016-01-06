require 'spec_helper'

describe OpenChain::Report::SqlProxyDataReport do
  
  class FakeReport
    include OpenChain::Report::SqlProxyDataReport
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
      data_conversions = {'a' => lambda{|r, v| v == 'A' ? "א" : v}, 'b' => lambda{|r, v| v == 'B' ? "ב" : v}}

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
      subject.should_receive(:worksheet_name).with(u, settings).and_return "Test"
      subject.should_receive(:column_headers).with(u, settings).and_return({'a' => "Aleph", 'b' => "Beit"})
      subject.should_receive(:report_filename).with(u, settings).and_return "file.xls"

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
      subject.should_receive(:worksheet_name).with(u, settings).and_return "Test"
      subject.should_receive(:column_headers).with(u, settings).and_return({'a' => "Aleph", 'b' => "Beit"})
      subject.should_receive(:report_filename).with(u, settings).and_return "file.xls"
      subject.should_receive(:get_data_conversions).with(u, settings).and_return({'a' => lambda{|r, v| v == 'A' ? "א" : v}, 'b' => lambda{|r, v| v == 'B' ? "ב" : v}})

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
      subject.class.should_receive(:sql_proxy_query_name).with(u, settings).and_return "test"

      c.should_receive(:report_query).with("test", {"a"=>"b"}, {'report_result_id'=>1})

      subject.class.run_report u, settings
    end

    it "sets up for call to sql proxy using custom parameters override" do
      u = User.new
      c = double("SqlProxyClient")
      settings = {"a" => "b", 'sql_proxy_client' => c, 'report_result_id'=>1}
      subject.class.should_receive(:sql_proxy_query_name).with(u, settings).and_return "test"
      subject.class.should_receive(:sql_proxy_parameters).with(u, settings).and_return({"custom"=>"params"})

      c.should_receive(:report_query).with("test", {"custom"=>"params"}, {'report_result_id'=>1})

      subject.class.run_report u, settings
    end
  end

  describe "process_alliance_query_details" do
    it "instantiates a new class instance and calls process results" do
      u = User.new
      results = []
      settings = {}

      subject.class.should_receive(:new_instance).with(u, results, settings).and_return subject
      subject.should_receive(:process_results).with(u, results, settings)

      subject.class.process_alliance_query_details u, results, settings
    end
  end
end
