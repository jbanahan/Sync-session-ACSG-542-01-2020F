describe OpenChain::Report::FenixCurrencyRatesReport do

  describe "schedulable_settings" do
    let (:user) { User.new time_zone: "Hawaii" }

    it "returns a start_date of yesterday in timezone associated with user" do
      # Freeze in UTC, the start date should be calc'ed to Hawaii time
      settings = nil
      Timecop.freeze(Time.zone.parse("2016-04-01 05:00")) do
        settings = described_class.schedulable_settings user, "Report", {}
      end

      expect(settings).to eq(settings: {'start_date' => '2016-03-30'}, friendly_settings: ["Exchange Rate Updated On or After 2016-03-30"] )
    end
  end

  describe "permission?" do

    before :each do
      ms = stub_master_setup_request_host
      allow(ms).to receive(:system_code).and_return "www-vfitrack-net"
    end

    it "allows master users permission" do
      expect(described_class.permission? FactoryBot(:master_user)).to be_truthy
    end

    it "disallows non-master user" do
      expect(described_class.permission? FactoryBot(:user)).to be_falsey
    end
  end


  describe "sql_proxy_parameters" do
    it "validates start_date is present" do
      expect {described_class.sql_proxy_parameters nil, {} }.to raise_error "A start date must be present."
    end

    it "formats parameters into expected reporting format" do
      values = described_class.sql_proxy_parameters nil, {'start_date' => "2016-04-01", 'end_date' => "2016-04-02", "countries" => "A\nB"}
      expect(values).to eq({'start_date' => "20160401", "end_date"=>"20160402", "countries"=>["A", "B"]})
    end
  end

  describe "run_report" do
    it "sends the expected sql proxy client command to run the sql_proxy server" do
      u = User.new
      client = instance_double(OpenChain::FenixSqlProxyClient)
      settings = {'start_date' => "2016-04-01", 'report_result_id' => 1, 'sql_proxy_client' => client}

      expect(client).to receive(:report_query).with("fenix_currency_rate_report", {"start_date" => "20160401"}, {'report_result_id' => 1})

      described_class.run_report u, settings
    end
  end

  describe "process_results" do
    after :each do
      @tf.close! if @tf
    end

    it "handles all post-query processing on data returned from sql_proxy server" do
      u = User.new
      results = [{'c'=>"CN", 'cn' => "China", "cur" => "CNY", "der" => "20160401", 'er' => "12.3456789"}]
      settings = {'start_date' => "2014-01-01"}

      @tf = subject.process_results u, results, settings
      expect(@tf.original_filename).to eq "CA Currency Rates On #{settings['start_date']}.xls"
      wb = Spreadsheet.open @tf.path
      sheet = wb.worksheets.find {|s| s.name == "CA Currency Rates"}
      expect(sheet).not_to be_nil
      expect(sheet.row(0)).to eq ["Country", "Name", "Currency", "Exchange Date", "Exchange Rate"]
      expect(sheet.row(1)).to eq ["CN", "China", "CNY", excel_date(Date.new(2016, 4, 1)), BigDecimal("12.345679")]
    end
  end
end