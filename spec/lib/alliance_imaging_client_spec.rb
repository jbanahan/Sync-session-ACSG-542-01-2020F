require 'spec_helper'

describe OpenChain::AllianceImagingClient do
  describe :bulk_request_images do
    before :each do
      @e1 = Factory(:entry,:broker_reference=>'123456',:source_system=>'Alliance')
      @e2 = Factory(:entry,:broker_reference=>'654321',:source_system=>'Alliance')
      @e3 = Factory(:entry,:broker_reference=>'777777',:source_system=>'Fenix')
    end
    it 'should request based on primary keys' do
      OpenChain::AllianceImagingClient.should_receive(:request_images).with('123456')
      OpenChain::AllianceImagingClient.should_receive(:request_images).with('654321')
      OpenChain::AllianceImagingClient.bulk_request_images nil, [@e1.id,@e2.id]
    end
    it 'should request based on search_run_id' do
      OpenChain::AllianceImagingClient.should_receive(:request_images).with('123456')
      OpenChain::AllianceImagingClient.should_receive(:request_images).with('654321')
      ss = Factory(:search_setup,:module_type=>"Entry",:user=>Factory(:master_user))
      ss.search
      OpenChain::AllianceImagingClient.bulk_request_images ss.search_run.id, nil
    end
    it 'should not request for non-alliance entries' do
      OpenChain::AllianceImagingClient.should_not_receive(:request_images)
      OpenChain::AllianceImagingClient.bulk_request_images nil, [@e3.id]
    end
  end
end
