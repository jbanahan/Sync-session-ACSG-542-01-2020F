require 'spec_helper'

describe Api::V1::EntriesController do
  let(:downloader) { OpenChain::ActivitySummary::EntrySummaryDownload }
  let(:imp) { Factory(:company) }
  let(:u) { Factory(:user) }
  before { allow_api_access u }

  describe "store_us_activity_summary_download" do
    it "runs report for authorized user" do
      imp_id = imp.id.to_s
      expect(downloader).to receive(:permission?).with(u, imp_id).and_return true
      expect(ReportResult).to receive(:run_report!).with("US Activity Summary", u, downloader, {:settings=>{iso_code: "US", importer_id: imp_id}})
      post :store_us_activity_summary_download, importer_id: imp_id
      expect(response.body).to eq({ok: "ok"}.to_json)
    end

    it "blocks unauthorized user" do
      imp_id = imp.id.to_s
      expect(downloader).to receive(:permission?).with(u, imp_id).and_return false
      expect(ReportResult).not_to receive(:run_report!)
      post :store_us_activity_summary_download, importer_id: imp_id
      expect(response).to be_forbidden
    end

    it "logs exceptions" do
      imp_id = imp.id.to_s
      expect(downloader).to receive(:permission?).with(u, imp_id).and_return true
      expect_any_instance_of(StandardError).to receive(:log_me)
      expect(ReportResult).to receive(:run_report!)
                          .with("US Activity Summary", u, downloader, {:settings=>{iso_code: "US", importer_id: imp_id}})
                          .and_raise "ERROR!"
      post :store_us_activity_summary_download, importer_id: imp_id
      expect(response.body).to eq({errors: ["There was an error running your report: ERROR!"]}.to_json)
    end
  end

  describe "store_ca_activity_summary_download" do
    it "delegates to store_activity_summary_download" do
      imp_id = imp.id.to_s
      expect_any_instance_of(described_class).to receive(:store_activity_summary_download).with "CA Activity Summary", "CA"
      post :store_ca_activity_summary_download, importer_id: imp_id
    end
  end
end
