require 'spec_helper'

describe OpenChain::CustomHandler::CrocsProductGenerator do
  describe :remote_file_name do
    it "should be in correct format" do
      described_class.new.remote_file_name.should match /[0-9]{17}-CROCS.DAT/
    end
  end
  describe :fixed_position_map do
    it "should return mapping" do
      described_class.new.fixed_position_map.should == [
          {:len=>40}, #part_number
          {:len=>40}, #name
          {:len=>10} #hts
      ]
    end
  end

end
