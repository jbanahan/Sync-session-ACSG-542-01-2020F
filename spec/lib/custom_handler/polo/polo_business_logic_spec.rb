require 'spec_helper'

describe OpenChain::CustomHandler::Polo::PoloBusinessLogic do
  before :each do 
    @logic = Class.new {extend OpenChain::CustomHandler::Polo::PoloBusinessLogic}
  end

  describe "sap_po?" do
    it 'identifies PO numbers starting with 47 as an SAP PO #' do
      expect(@logic.sap_po? "47").to be_true
    end

    it "doesn't take leading space into account when identifying an SAP PO" do
      expect(@logic.sap_po? "    \t47").to be_true
    end

    it 'identifies non-sap PO numbers' do
      expect(@logic.sap_po? "4").to be_false
    end
  end

  describe "split_sap_po_line_number" do
    it "splits an SAP PO number into PO / Line" do
      expect(@logic.split_sap_po_line_number("123-10")).to eq ["123", "10"]
    end

    it "strips leading zeros from line number" do
      expect(@logic.split_sap_po_line_number("123-010")).to eq ["123", "10"]
    end

    it "adds missing trailing zeros to line number" do
      expect(@logic.split_sap_po_line_number("123-1")).to eq ["123", "10"]
    end

    it "handles extra hyphens" do
      expect(@logic.split_sap_po_line_number("123-2-1")).to eq ["123-2", "10"]
    end

    it "gracefully handles malformed numbers" do
      expect(@logic.split_sap_po_line_number("123-abc")).to eq ["123-abc", ""]
    end
  end

  describe "prepack_indicator?" do
    it "identifies prepack code" do
      expect(@logic.prepack_indicator? "AS").to be_true
      expect(@logic.prepack_indicator? "as").to be_true
      expect(@logic.prepack_indicator? " as").to be_true
      expect(@logic.prepack_indicator? " as ").to be_true

      expect(@logic.prepack_indicator? "EA").to be_false
    end
  end
end