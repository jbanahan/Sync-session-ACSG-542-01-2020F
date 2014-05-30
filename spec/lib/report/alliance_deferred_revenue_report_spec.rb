require 'spec_helper'

describe OpenChain::Report::AllianceDeferredRevenueReport do

  describe "permission?" do
    it "grants permission to vfitrack Luca, bglick, jhulford users" do
      d = double("MasterSetup")
      MasterSetup.stub(:get).and_return d
      d.stub(:system_code).and_return "www-vfitrack-net"

      expect(described_class.permission? User.new(username:'Luca')).to be_true
      expect(described_class.permission? User.new(username:'jhulford')).to be_true
      expect(described_class.permission? User.new(username:'bglick')).to be_true
    end

    it "does not allow plain users" do
      u = Factory(:user)
      d = double("MasterSetup")
      MasterSetup.should_receive(:get).and_return d
      d.should_receive(:system_code).and_return "www-vfitrack-net"

      expect(described_class.permission? u).to be_false
    end

    it "does not allow non-vfitrack usage" do
      u = Factory(:master_user)
      expect(described_class.permission? u).to be_false
    end
  end

  describe "run_report" do
    it "handles all pre-query setup" do
      u = User.new
      client = double("SqlProxyClient")
      settings = {'start_date' => "2014-01-01", "end_date"=>"2014-01-02", 'report_result_id' => 1, 'sql_proxy_client' => client}

      client.should_receive(:report_query).with("deferred_revenue", {:start_date => "20140101", :end_date =>"20140102"}, {'report_result_id' => 1})

      described_class.run_report u, settings
    end
  end

  describe "process_results" do
    after :each do
      @tf.close! if @tf
    end
    
    it "handles all post-query processing" do
      u = User.new
      results = [{'bf'=>"12345", 'ff' => "98765", 'dr' => "12.5"}]
      settings = {'start_date' => "2014-01-01", "end_date"=>"2014-01-02"}

      @tf = described_class.new.process_results u, results, settings
      expect(File.basename(@tf.path)).to start_with "Deferred Revenue From #{settings['start_date']} To #{settings['end_date']} - "
      wb = Spreadsheet.open @tf.path
      sheet = wb.worksheets.find {|s| s.name == "Deferred Revenue"}
      expect(sheet).not_to be_nil
      expect(sheet.row(0)).to eq ["Broker File Number", "Freight File", "Revenue To Defer"]
      expect(sheet.row(1)).to eq ["12345", "98765", 12.5]
    end
  end
end