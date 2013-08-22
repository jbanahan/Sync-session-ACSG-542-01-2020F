require 'spec_helper'
require 'net/https'

describe OpenChain::StatClient do
  describe :collect_total_products do
    it "should call add_numeric with appropriate params" do
      t = Time.now
      Time.stub(:now).and_return(t)
      3.times {Factory(:product)}
      described_class.should_receive(:add_numeric).with('tot_prod',3,t)
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
      pst = mock('post')
      @path = '/api/something'
      Net::HTTP::Post.should_receive(:new).with(@path).and_return(pst)
      pst.should_receive(:set_content_type).with('application/json')
      pst.should_receive(:body=).with({mykey:'myval',api_key:@api_key,uuid:@uuid}.to_json)
      @http.should_receive(:request).with pst
    end
    it "should add api_key and uuid" do
      resp = mock('resp')
      resp.should_receive(:code).and_return '200'
      Net::HTTP.should_receive(:start).with('localhost',3001).and_yield(@http).and_return(resp)
      described_class.post_json! @path, {mykey:'myval'}
    end
    it "should raise exception for non 200 responses" do
      resp = mock('resp')
      resp.should_receive(:code).and_return '400'
      resp.should_receive(:body).and_return({:error=>'my error'}.to_json)
      Net::HTTP.should_receive(:start).with('localhost',3001).and_yield(@http).and_return(resp)
      lambda {described_class.post_json! @path, {mykey:'myval'}}.should raise_error 'Request Error: my error'
    end
  end
end
