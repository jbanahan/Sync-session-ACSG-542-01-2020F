require 'spec_helper'

describe Api::V1::AllianceReportsController do
  before :each do
    @user = Factory(:admin_user, api_auth_token: "Token")
    allow_api_access @user
  end

  describe "receive_alliance_report_data" do
    it "receives report data and delays control through to the specified report result instance" do
      rr = ReportResult.create! status: "RunNinG"

      query_results = [{"key" => "value"}]
      query_context = {"report_result_id" => rr.id}

      expect_any_instance_of(ReportResult).to receive(:delay).and_return rr
      expect(rr).to receive(:continue_alliance_report).with query_results.to_json

      post "receive_alliance_report_data", results: query_results, context: query_context
      expect(response.body).to eq ({"OK" => ""}.to_json)
    end

    it "logs an error if report result is missing" do
      query_results = [{"key" => "value"}]
      query_context = {"report_result_id" => -1}

      expect_any_instance_of(StandardError).to receive(:log_me)

      post "receive_alliance_report_data", results: query_results, context: query_context
      expect(response.body).to eq ({"OK" => ""}.to_json)
    end

    it "logs an error if report result is not running" do
      rr = ReportResult.create! status: "Error"
      query_results = [{"key" => "value"}]
      query_context = {"report_result_id" => rr.id}

      expect_any_instance_of(StandardError).to receive(:log_me)
      post "receive_alliance_report_data", results: query_results, context: query_context
      expect(response.body).to eq ({"OK" => ""}.to_json)
    end

    it "handles missing report result id" do
      query_results = [{"key" => "value"}]
      query_context = {}

      expect_any_instance_of(StandardError).to receive(:log_me)
      post "receive_alliance_report_data", results: query_results, context: query_context
      expect(response.body).to eq ({"OK" => ""}.to_json)
    end

    it "passes through blank result data" do
      rr = ReportResult.create! status: "RunNinG"

      query_results = nil
      query_context = {"report_result_id" => rr.id}

      expect_any_instance_of(ReportResult).to receive(:delay).and_return rr
      expect(rr).to receive(:continue_alliance_report).with [].to_json

      post "receive_alliance_report_data", results: query_results, context: query_context
      expect(response.body).to eq ({"OK" => ""}.to_json)
    end
  end
end