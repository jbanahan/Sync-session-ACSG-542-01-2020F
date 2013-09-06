require 'spec_helper'
require 'net/https'

describe OpenChain::StatClient do
  def prep_time
    t = Time.now
    Time.stub(:now).and_return(t)
    t
  end

  describe :run do
    before :each do
      described_class.stub(:post_json!)
    end
    it "should only call active users on base install" do
      dont_call = [:collect_total_products,:collect_total_entries,:collect_total_surveys,
        :collect_total_survey_responses,:collect_report_recipients]
      dont_call.each {|c| described_class.should_not_receive(c)}
      described_class.should_receive(:collect_active_users)
      described_class.run
    end
    it "should call products if there are products" do
      Factory(:product)
      described_class.should_receive(:collect_total_products)
      described_class.run
    end
    it "should call entries if there are entries" do
      Factory(:entry)
      described_class.should_receive(:collect_total_entries)
      described_class.run
    end
    it "should call surveys & survey_responses if there are surveys" do
      Factory(:survey)
      described_class.should_receive(:collect_total_surveys)
      described_class.should_receive(:collect_total_survey_responses)
      described_class.run
    end
    it "should call report_recipients if there are search_schedules" do
      Factory(:search_schedule)
      described_class.should_receive(:collect_report_recipients)
      described_class.run
    end
  end
  describe :collect_report_recipients do
    it "should only report unique addresses" do
      Factory(:search_schedule,email_addresses:'joe@sample.com, mary@sample.com')
      Factory(:search_schedule,email_addresses:'fred@sample.com,joe@sample.com')
      described_class.should_receive(:add_numeric).with('rep_recipients',3,prep_time)
      described_class.collect_report_recipients
    end
    it "should not include vandegriftinc.com addresses" do
      Factory(:search_schedule,email_addresses:'joe@sample.com, mary@vandegriftinc.com')
      described_class.should_receive(:add_numeric).with('rep_recipients',1,prep_time)
      described_class.collect_report_recipients
    end
  end
  describe :collect_active_users do
    it "should call add_numeric with appropriate params" do
      User.scoped.destroy_all # some other test case may be leaving a record behind
      Factory(:user,last_request_at:8.days.ago) #too old
      Factory(:user) #never requested
      Factory(:user,last_request_at:5.days.ago)
      Factory(:user,last_request_at:3.days.ago)
      described_class.should_receive(:add_numeric).with('u_act_7',2,prep_time)
      described_class.collect_active_users
    end
  end
  describe :collect_total_survey_responses do
    it "should call add_numeric with appropriate params" do
      m = double('scoped')
      m.should_receive(:count).and_return 3
      SurveyResponse.stub(:scoped).and_return m
      described_class.should_receive(:add_numeric).with('tot_survey_resp',3,prep_time)
      described_class.collect_total_survey_responses
    end
  end
  describe :collect_total_surveys do
    it "should call add_numeric with appropriate params" do
      m = double('scoped')
      m.should_receive(:count).and_return 3
      Survey.stub(:scoped).and_return m
      described_class.should_receive(:add_numeric).with('tot_survey',3,prep_time)
      described_class.collect_total_surveys
    end
  end
  describe :collect_total_entries do
    it "should call add_numeric with appropriate params" do
      m = double('scoped entry')
      m.should_receive(:count).and_return 3
      Entry.stub(:scoped).and_return m
      described_class.should_receive(:add_numeric).with('tot_ent',3,prep_time)
      described_class.collect_total_entries
    end
  end
  describe :collect_total_products do
    it "should call add_numeric with appropriate params" do
      m = double('scoped product')
      m.should_receive(:count).and_return 3
      Product.stub(:scoped).and_return m
      described_class.should_receive(:add_numeric).with('tot_prod',3,prep_time)
      described_class.collect_total_products
    end
  end
  describe :add_numeric do
    it "should set url and json" do
      t = 1.hour.ago
      described_class.should_receive(:post_json!).with('/api/v1/stat_collector/add_numeric',{stat_code:'scode',value:10,collected_at:t})
      described_class.add_numeric 'scode', 10, t
    end
  end

  describe :post_json do
    before :each do 
      ms = MasterSetup.get
      ms.update_attributes(stats_api_key:'sapi')
      @api_key = ms.stats_api_key
      @uuid = ms.uuid
      @http = mock('http')
      @pst = mock('post')
      @path = '/api/something'
      Net::HTTP::Post.should_receive(:new).with(@path).and_return(@pst)
      @pst.should_receive(:set_content_type).with('application/json')
      @pst.should_receive(:set_form_data).with({mykey:'myval',api_key:@api_key,uuid:@uuid})
    end
    it "should add api_key and uuid" do
      resp = mock('resp')
      resp.should_receive(:code).and_return '200'
      Net::HTTP.should_receive(:new).with('localhost',3001).and_return(@http)
      @http.should_receive(:request).with(@pst).and_return(resp)
      described_class.post_json! @path, {mykey:'myval'}
    end
    it "should raise exception for non 200 responses" do
      resp = mock('resp')
      resp.should_receive(:code).and_return '400'
      resp.should_receive(:body).and_return({:error=>'my error'}.to_json)
      Net::HTTP.should_receive(:new).with('localhost',3001).and_return(@http)
      @http.should_receive(:request).with(@pst).and_return(resp)
      lambda {described_class.post_json! @path, {mykey:'myval'}}.should raise_error 'Request Error: my error'
    end
  end
end
