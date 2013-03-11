require 'spec_helper'

describe OpenChain::CustomHandler::DasProductGenerator do
  #YYYYMMDDHHMMSSLLL-DAPART.DAT
  describe :remote_file_name do
    it "should be in correct format" do
      described_class.new.remote_file_name.should match /[0-9]{17}-DAPART\.DAT/
    end
  end

  describe :fixed_position_map do
    it "should return mapping" do
      described_class.new.fixed_position_map.should == [
        {:len=>15}, #unique identifier
        {:len=>40}, #name
        {:len=>6}, #unit cost
        {:len=>2}, #country of origin
        {:len=>10} #hts
      ]
    end
  end
end
