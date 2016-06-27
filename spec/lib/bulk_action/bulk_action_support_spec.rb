require 'spec_helper'
require 'open_chain/bulk_action/bulk_action_support'

describe OpenChain::BulkAction::BulkActionSupport do
  
  describe '#get_bulk_count' do
    before :each do
      my_k = Class.new do
       include OpenChain::BulkAction::BulkActionSupport
     end
     @counter = my_k.new
    end
    
    it 'should get count for specific items' do
      p = {"0"=>"99","1"=>"54"}
      expect(@counter.get_bulk_count p, nil).to eq 2
    end
    it 'should get count for full search update' do
      sr = double('search_run')
      sr.should_receive(:total_objects).and_return 10
      SearchRun.should_receive(:find_by_id).with('99').and_return sr
      expect(@counter.get_bulk_count(nil, '99')).to eq 10
    end
  end
end