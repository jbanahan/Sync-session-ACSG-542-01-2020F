require 'spec_helper'

describe OpenChain::EntityCompare::ComparatorHelper do
  subject {
    Class.new do
      include OpenChain::EntityCompare::ComparatorHelper
    end.new
  }
  describe '#get_json_hash' do
    it "should get data from S3" do
      h = {'a'=>'b'}
      json = h.to_json
      OpenChain::S3.should_receive(:get_versioned_data).with('b','k','v').and_return json
      expect(subject.get_json_hash('b','k','v')).to eq h
    end

    it "returns blank hash if bucket is blank" do
      expect(subject.get_json_hash('','k','v')).to eq({})
    end

    it "returns blank hash if key is blank" do
      expect(subject.get_json_hash('b','','v')).to eq({})
    end

    it "returns blank hash if version is blank" do
      expect(subject.get_json_hash('b','k','')).to eq({})
    end

    it "returns blank if data is blank" do
      OpenChain::S3.should_receive(:get_versioned_data).with('b','k','v').and_return "       "
      expect(subject.get_json_hash('b','k','v')).to eq({})
    end
  end

end
