describe OpenChain::Report::AllianceDeferredRevenueReport do

  describe "permission?" do
    it "grants permission to users in accounting group" do
      d = double("MasterSetup")
      allow(MasterSetup).to receive(:get).and_return d
      allow(d).to receive(:system_code).and_return "www-vfitrack-net"

      u = Factory(:user)
      u.groups << Group.use_system_group("intacct-accounting")

      expect(described_class.permission? u).to be_truthy
    end

    it "does not allow plain users" do
      u = Factory(:user)
      d = double("MasterSetup")
      expect(MasterSetup).to receive(:get).and_return d
      expect(d).to receive(:system_code).and_return "www-vfitrack-net"

      expect(described_class.permission? u).to be_falsey
    end

    it "does not allow non-vfitrack usage" do
      u = Factory(:master_user)
      expect(described_class.permission? u).to be_falsey
    end
  end

  describe "run_report" do
    it "handles all pre-query setup" do
      u = User.new
      client = double("SqlProxyClient")
      settings = {'start_date' => "2014-01-01", 'report_result_id' => 1, 'sql_proxy_client' => client}

      expect(client).to receive(:report_query).with("deferred_revenue", {:start_date => "20140101"}, {'report_result_id' => 1})

      described_class.run_report u, settings
    end
  end

  describe "process_results" do
    after :each do
      @tf.close! if @tf
    end

    it "handles all post-query processing" do
      u = User.new
      results = [{'bf'=>"12345", 'ff' => "98765", "bid" => "2014-01-01", "c" => "CUST", 'dr' => "12.5", "fid" => "2014-02-01"}]
      settings = {'start_date' => "2014-01-01"}

      @tf = described_class.new.process_results u, results, settings
      expect(@tf.original_filename).to eq "Deferred Revenue On #{settings['start_date']}.xls"
      wb = Spreadsheet.open @tf.path
      sheet = wb.worksheets.find {|s| s.name == "Deferred Revenue"}
      expect(sheet).not_to be_nil
      expect(sheet.row(0)).to eq ["Broker File #", "Freight File #", "Brokerage Invoice Date", "Cust #", "Deferred Revenue", "Freight Invoice Date"]
      expect(sheet.row(1)).to eq ["12345", "98765", "2014-01-01", "CUST", 12.5, "2014-02-01"]
    end
  end
end