require 'spec_helper'

describe OpenChain::EntityCompare::ComparatorHelper do
  describe '#get_json_hash' do
    it "should get data from S3" do
      k = Class.new do
        extend OpenChain::EntityCompare::ComparatorHelper
      end
      h = {'a'=>'b'}
      json = h.to_json
      OpenChain::S3.should_receive(:get_versioned_data).with('b','k','v').and_return json
      expect(k.get_json_hash('b','k','v')).to eq h
    end
  end
end
