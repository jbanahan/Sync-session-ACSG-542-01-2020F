describe OpenChain::StatClient do
  let (:prep_time) { Time.now }

  around (:each) do |ex|
    Timecop.freeze(prep_time) do
      ex.run
    end
  end

  subject { described_class }

  describe "run" do
    before :each do
      allow(subject).to receive(:post_json!)
    end
    it "should only call active users on base install" do
      dont_call = [:collect_total_products, :collect_total_entries, :collect_total_surveys,
        :collect_total_survey_responses, :collect_report_recipients]
      dont_call.each {|c| expect(subject).not_to receive(c)}
      expect(subject).to receive(:collect_active_users)
      subject.run
    end
    it "should call products if there are products" do
      create(:product)
      expect(subject).to receive(:collect_total_products)
      subject.run
    end
    it "should call entries if there are entries" do
      create(:entry)
      expect(subject).to receive(:collect_total_entries)
      subject.run
    end
    it "should call surveys & survey_responses if there are surveys" do
      create(:survey)
      expect(subject).to receive(:collect_total_surveys)
      expect(subject).to receive(:collect_total_survey_responses)
      subject.run
    end
    it "should call report_recipients if there are search_schedules" do
      create(:search_schedule)
      expect(subject).to receive(:collect_report_recipients)
      subject.run
    end
  end
  describe "wall_time" do
    it "should measure wall time for process using Time.now" do
      allow(Time).to receive(:now).and_return(20, 30)
      expect(subject).to receive(:add_numeric).with('mycode', 10)
      subject.wall_time('mycode') { nil }
    end
  end
  describe "collect_report_recipients" do
    it "should only report unique addresses" do
      create(:search_schedule, email_addresses:'joe@sample.com, jim@sample.com; mary@sample.com')
      create(:search_schedule, email_addresses:'fred@sample.com,joe@sample.com')
      expect(subject).to receive(:add_numeric).with('rep_recipients', 4, prep_time)
      subject.collect_report_recipients
    end
    it "should not include vandegriftinc.com addresses" do
      create(:search_schedule, email_addresses:'joe@sample.com, mary@vandegriftinc.com')
      expect(subject).to receive(:add_numeric).with('rep_recipients', 1, prep_time)
      subject.collect_report_recipients
    end
  end
  describe "collect_active_users" do
    it "should call add_numeric with appropriate params" do
      create(:user, username:'ca2', last_request_at:Time.zone.now)
      create(:user, username:'ca1', last_request_at:8.days.ago) # too old
      create(:user, username:'ca3', last_request_at:5.days.ago)
      create(:user, username:'ca4', last_request_at:nil) # never requested
      expect(subject).to receive(:add_numeric).with('u_act_7', 2, prep_time)
      subject.collect_active_users
    end
  end
  describe "collect_total_survey_responses" do
    before :each do
      create(:survey_response)
      create(:survey_response)
    end

    it "should call add_numeric with appropriate params" do
      expect(subject).to receive(:add_numeric).with('tot_survey_resp', 2, prep_time)
      subject.collect_total_survey_responses
    end
  end
  describe "collect_total_surveys" do
    before :each do
      create(:survey)
      create(:survey)
    end

    it "should call add_numeric with appropriate params" do
      expect(subject).to receive(:add_numeric).with('tot_survey', 2, prep_time)
      subject.collect_total_surveys
    end
  end
  describe "collect_total_entries" do
    before :each do
      create(:entry)
      create(:entry)
    end

    it "should call add_numeric with appropriate params" do
      expect(subject).to receive(:add_numeric).with('tot_ent', 2, prep_time)
      subject.collect_total_entries
    end
  end
  describe "collect_total_products" do
    before :each do
      create(:product)
      create(:product)
    end

    it "should call add_numeric with appropriate params" do
      expect(subject).to receive(:add_numeric).with('tot_prod', 2, prep_time)
      subject.collect_total_products
    end
  end
  describe "add_numeric" do
    it "should set url and json" do
      t = 1.hour.ago
      dbl = double('stat_client')
      expect(subject).to receive(:delay).and_return(dbl)
      expect(dbl).to receive(:post_json!).with('/api/v1/stat_collector/add_numeric', {stat_code:'scode', value:10, collected_at:t})
      subject.add_numeric 'scode', 10, t
    end
  end

  describe "post_json" do
    let (:stats_server_config) {
      {"vfi_stats" => {"base_url" => "http://localhost:3001"}}
    }

    let (:api_key) { 'sapi'}
    let! (:master_setup) {
      ms = stub_master_setup
      allow(ms).to receive(:stats_api_key).and_return api_key
      ms
    }

    let (:api_path) { '/api_something'}
    let (:http) { double('http') }
    let (:post) { double("post") }

    def enable_http_mocks
      expect(Net::HTTP::Post).to receive(:new).with(api_path).and_return(post)
      expect(post).to receive(:set_content_type).with('application/json')
      expect(post).to receive(:set_form_data).with({mykey:'myval', api_key:api_key, uuid:master_setup.uuid})
    end

    it 'should not do anything if stats_api_key is not set' do
      expect(master_setup).to receive(:stats_api_key).and_return nil
      expect(Net::HTTP::Post).not_to receive(:new)
      subject.post_json! api_path, {mykey:'myval'}
    end
    it "should add api_key and uuid" do
      enable_http_mocks
      resp = double('resp')
      expect(resp).to receive(:code).and_return '200'
      expect(Net::HTTP).to receive(:new).with('localhost', 3001).and_return(http)
      expect(http).to receive(:request).with(post).and_return(resp)
      expect(MasterSetup).to receive(:secrets).and_return(stats_server_config)
      subject.post_json! api_path, {mykey:'myval'}
    end
    it "should raise exception for non 200 responses" do
      enable_http_mocks
      resp = double('resp')
      expect(MasterSetup).to receive(:secrets).and_return(stats_server_config)
      expect(resp).to receive(:code).and_return '400'
      expect(resp).to receive(:body).and_return({:error=>'my error'}.to_json)
      expect(Net::HTTP).to receive(:new).with('localhost', 3001).and_return(http)
      expect(http).to receive(:request).with(post).and_return(resp)
      expect {subject.post_json! api_path, {mykey:'myval'}}.to raise_error 'Request Error: my error'
    end
  end

  describe "run_schedulable" do
    it "implements SchedulableJob interface" do
      expect(OpenChain::StatClient).to receive(:run)
      OpenChain::StatClient.run_schedulable
    end
  end
end
