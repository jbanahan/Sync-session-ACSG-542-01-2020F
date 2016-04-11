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

  describe "parse_time" do
    it "parses time from utc to eastern" do
      expect(subject.parse_time("2016-04-08 8:44")).to eq ActiveSupport::TimeZone['America/New_York'].parse("2016-04-08 4:44")
    end

    it "parses time using given timezones" do
       expect(subject.parse_time("2016-04-08 8:44", input_timezone: 'America/New_York', output_timezone: 'America/Chicago')).to eq ActiveSupport::TimeZone['America/Chicago'].parse("2016-04-08 7:44")
    end

    it "returns nil if time is blank" do
      expect(subject.parse_time("   ")).to be_nil
    end 
  end
end
