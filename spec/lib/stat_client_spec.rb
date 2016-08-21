require 'spec_helper'
require 'net/https'

describe OpenChain::StatClient do
  def prep_time
    t = Time.now
    allow(Time).to receive(:now).and_return(t)
    t
  end

  describe "run" do
    before :each do
      allow(described_class).to receive(:post_json!)
    end
    it "should only call active users on base install" do
      dont_call = [:collect_total_products,:collect_total_entries,:collect_total_surveys,
        :collect_total_survey_responses,:collect_report_recipients]
      dont_call.each {|c| expect(described_class).not_to receive(c)}
      expect(described_class).to receive(:collect_active_users)
      described_class.run
    end
    it "should call products if there are products" do
      Factory(:product)
      expect(described_class).to receive(:collect_total_products)
      described_class.run
    end
    it "should call entries if there are entries" do
      Factory(:entry)
      expect(described_class).to receive(:collect_total_entries)
      described_class.run
    end
    it "should call surveys & survey_responses if there are surveys" do
      Factory(:survey)
      expect(described_class).to receive(:collect_total_surveys)
      expect(described_class).to receive(:collect_total_survey_responses)
      described_class.run
    end
    it "should call report_recipients if there are search_schedules" do
      Factory(:search_schedule)
      expect(described_class).to receive(:collect_report_recipients)
      described_class.run
    end
  end
  describe "wall_time" do
    it "should measure wall time for process using Time.now" do
      allow(Time).to receive(:now).and_return(20,30)
      expect(described_class).to receive(:add_numeric).with('mycode',10)
      described_class.wall_time('mycode') { nil }
    end
  end
  describe "collect_report_recipients" do
    it "should only report unique addresses" do
      Factory(:search_schedule,email_addresses:'joe@sample.com, jim@sample.com; mary@sample.com')
      Factory(:search_schedule,email_addresses:'fred@sample.com,joe@sample.com')
      expect(described_class).to receive(:add_numeric).with('rep_recipients',4,prep_time)
      described_class.collect_report_recipients
    end
    it "should not include vandegriftinc.com addresses" do
      Factory(:search_schedule,email_addresses:'joe@sample.com, mary@vandegriftinc.com')
      expect(described_class).to receive(:add_numeric).with('rep_recipients',1,prep_time)
      described_class.collect_report_recipients
    end
  end
  describe "collect_active_users" do
    it "should call add_numeric with appropriate params" do
      Factory(:user,username:'ca2',last_request_at:Time.zone.now)
      Factory(:user,username:'ca1',last_request_at:8.days.ago) #too old
      Factory(:user,username:'ca3',last_request_at:5.days.ago)
      Factory(:user,username:'ca4',last_request_at:nil) #never requested
      expect(described_class).to receive(:add_numeric).with('u_act_7',2,prep_time)
      described_class.collect_active_users
    end
  end
  describe "collect_total_survey_responses" do
    it "should call add_numeric with appropriate params" do
      m = double('scoped')
      expect(m).to receive(:count).and_return 3
      allow(SurveyResponse).to receive(:scoped).and_return m
      expect(described_class).to receive(:add_numeric).with('tot_survey_resp',3,prep_time)
      described_class.collect_total_survey_responses
    end
  end
  describe "collect_total_surveys" do
    it "should call add_numeric with appropriate params" do
      m = double('scoped')
      expect(m).to receive(:count).and_return 3
      allow(Survey).to receive(:scoped).and_return m
      expect(described_class).to receive(:add_numeric).with('tot_survey',3,prep_time)
      described_class.collect_total_surveys
    end
  end
  describe "collect_total_entries" do
    it "should call add_numeric with appropriate params" do
      m = double('scoped entry')
      expect(m).to receive(:count).and_return 3
      allow(Entry).to receive(:scoped).and_return m
      expect(described_class).to receive(:add_numeric).with('tot_ent',3,prep_time)
      described_class.collect_total_entries
    end
  end
  describe "collect_total_products" do
    it "should call add_numeric with appropriate params" do
      m = double('scoped product')
      expect(m).to receive(:count).and_return 3
      allow(Product).to receive(:scoped).and_return m
      expect(described_class).to receive(:add_numeric).with('tot_prod',3,prep_time)
      described_class.collect_total_products
    end
  end
  describe "add_numeric" do
    it "should set url and json" do
      t = 1.hour.ago
      dbl = double('stat_client')
      expect(described_class).to receive(:delay).and_return(dbl)
      expect(dbl).to receive(:post_json!).with('/api/v1/stat_collector/add_numeric',{stat_code:'scode',value:10,collected_at:t})
      described_class.add_numeric 'scode', 10, t
    end
  end

  describe "post_json" do
    before :each do 
      ms = MasterSetup.get
      ms.update_attributes(stats_api_key:'sapi')
      @api_key = ms.stats_api_key
      @uuid = ms.uuid
      @path = '/api/something'
    end
    def enable_http_mocks
      @http = double('http')
      @pst = double('post')
      expect(Net::HTTP::Post).to receive(:new).with(@path).and_return(@pst)
      expect(@pst).to receive(:set_content_type).with('application/json')
      expect(@pst).to receive(:set_form_data).with({mykey:'myval',api_key:@api_key,uuid:@uuid})
    end
    it 'should not do anything if stats_api_key is not set' do
      MasterSetup.get.update_attributes(stats_api_key:nil)
      expect(Net::HTTP::Post).not_to receive(:new)
      described_class.post_json! @path, {mykey:'myval'}
    end
    it "should add api_key and uuid" do
      enable_http_mocks
      resp = double('resp')
      expect(resp).to receive(:code).and_return '200'
      expect(Net::HTTP).to receive(:new).with('localhost',3001).and_return(@http)
      expect(@http).to receive(:request).with(@pst).and_return(resp)
      described_class.post_json! @path, {mykey:'myval'}
    end
    it "should raise exception for non 200 responses" do
      enable_http_mocks
      resp = double('resp')
      expect(resp).to receive(:code).and_return '400'
      expect(resp).to receive(:body).and_return({:error=>'my error'}.to_json)
      expect(Net::HTTP).to receive(:new).with('localhost',3001).and_return(@http)
      expect(@http).to receive(:request).with(@pst).and_return(resp)
      expect {described_class.post_json! @path, {mykey:'myval'}}.to raise_error 'Request Error: my error'
    end
  end

  describe "run_schedulable" do
    it "implements SchedulableJob interface" do
      expect(OpenChain::StatClient).to receive(:run)
      OpenChain::StatClient.run_schedulable
    end
  end
end
