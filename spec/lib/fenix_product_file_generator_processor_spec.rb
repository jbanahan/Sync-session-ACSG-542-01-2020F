require 'spec_helper'
require 'open_chain/custom_handler/fenix_product_file_generator'

describe OpenChain::FenixProductFileGeneratorProcessor do
  before :each do
    @canada = Factory(:country, iso_code: "CA")
    @fpfgp = OpenChain::FenixProductFileGeneratorProcessor.new
  end

  describe :run_schedulable do
    it "should pass in all possible options when provided" do
      @fpfg1 = OpenChain::CustomHandler::FenixProductFileGenerator.new("XYZ","23",false,"5 > 3")
      hash = {"fenix_customer_code" => "XYZ", "importer_id" => "23",
          "use_part_number" => "false", "additional_where" => "5 > 3"}
      OpenChain::CustomHandler::FenixProductFileGenerator.should_receive(:new).with(
        "XYZ","23",false,"5 > 3").and_return(@fpfg1)
      OpenChain::CustomHandler::FenixProductFileGenerator.any_instance.should_receive(:generate)
      @fpfgp.run_schedulable(hash)
    end

    it "should convert strings of true into keywords of true" do
      @fpfg2 = OpenChain::CustomHandler::FenixProductFileGenerator.new("XYZ","23",true,"5 > 3")
      hash = {"fenix_customer_code" => "XYZ", "importer_id" => "23",
          "use_part_number" => "true", "additional_where" => "5 > 3"}
      OpenChain::CustomHandler::FenixProductFileGenerator.should_receive(:new).with(
        "XYZ","23",true,"5 > 3").and_return(@fpfg2)
      OpenChain::CustomHandler::FenixProductFileGenerator.any_instance.should_receive(:generate)
      @fpfgp.run_schedulable(hash)
    end

    it "should not fail on missing options" do
      @fpfg3 = OpenChain::CustomHandler::FenixProductFileGenerator.new("XYZ","23")
      hash = {"fenix_customer_code" => "XYZ", "importer_id" => "23"}
      OpenChain::CustomHandler::FenixProductFileGenerator.should_receive(:new).with(
        "XYZ","23", false, nil).and_return(@fpfg3)
      OpenChain::CustomHandler::FenixProductFileGenerator.any_instance.should_receive(:generate)
      @fpfgp.run_schedulable(hash)
    end
  end
end