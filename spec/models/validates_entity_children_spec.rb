require 'spec_helper'

describe ValidatesEntityChildren do
  before :each do
    @line = Factory(:commercial_invoice_line, po_number: "ABC")
    @line_2 = Factory(:commercial_invoice_line, po_number: "DEF", commercial_invoice: @line.commercial_invoice)
    @entry = @line.entry
    
    # Create a simple class that validates a commercial invoice line
    @v = Class.new(BusinessValidationRule) {
      include ValidatesEntityChildren 

      def module_chain
        [CoreModule::ENTRY, CoreModule::COMMERCIAL_INVOICE, CoreModule::COMMERCIAL_INVOICE_LINE]
      end

      def child_objects entry
        entry.commercial_invoice_lines
      end

      def module_chain_entities invoice_line
        {CoreModule::ENTRY => invoice_line.entry, CoreModule::COMMERCIAL_INVOICE => invoice_line.commercial_invoice, CoreModule::COMMERCIAL_INVOICE_LINE => invoice_line}
      end
    }.new
  end

  describe "run_validation" do
    it "validates child objects" do
      @v.should_receive(:run_child_validation).with(@entry.commercial_invoice_lines.first).and_return ""
      @v.should_receive(:run_child_validation).with(@entry.commercial_invoice_lines.second).and_return ""
      expect(@v.run_validation(@entry)).to be_nil
    end

    it "returns errors for each object" do
      @v.should_receive(:run_child_validation).with(@entry.commercial_invoice_lines.first).and_return "Error 1"
      @v.should_receive(:run_child_validation).with(@entry.commercial_invoice_lines.second).and_return "Error 2"
      expect(@v.run_validation(@entry)).to eq "Error 1\nError 2"
    end

    it "skip lines that don't match child level search criteria" do
      @v.search_criterions.build model_field_uid:'cil_po_number',operator:'eq',value:'ABC'
      @v.should_receive(:run_child_validation).with(@entry.commercial_invoice_lines.first).and_return "Error 1"

      expect(@v.run_validation(@entry)).to eq "Error 1"
    end

    it "skip lines that don't match header level search criteria" do
      @v.search_criterions.build model_field_uid:'ent_entry_num',operator:'eq',value:'123'
      @v.should_not_receive(:run_child_validation)

      expect(@v.run_validation(@entry)).to be_nil
    end

    it "doesn't validated children if stop is called" do
      # Since we're calling stop, the second line shouldn't be evaluated.
      @v.should_receive(:run_child_validation).with(@entry.commercial_invoice_lines.first) do |param|
        @v.stop_validation
        "Error"
      end

      expect(@v.run_validation(@entry)).to eq "Error"
      # This is peeking below the covers, but I want to make sure the stopped flag is destroyed after it's needed
      # so it's definitely not left around in case the rule object is re-used
      expect(@v.instance_variables).not_to include(:@validation_stopped)
    end

    it "calls setup_validation if defined" do
      @v.should_receive(:setup_validation)
      @v.should_receive(:run_child_validation).exactly(2).times
      expect(@v.run_validation(@entry)).to be_nil
    end
  end

  describe "should_skip?" do
    it "skips validation when no search criterion matches" do
      @v.search_criterions.build model_field_uid:'ent_entry_num',operator:'eq',value:'123'
      expect(@v.should_skip?(@entry)).to be_true
    end

    it "does not skip validation when search criterion matches header" do
      @v.search_criterions.build model_field_uid:'ent_entry_num', operator:'null'
      expect(@v.should_skip?(@entry)).to be_false
    end

    it "does not skip validation when search criterion matches a single child" do
      @v.search_criterions.build model_field_uid:'cil_po_number',operator:'eq',value:'ABC'
      expect(@v.should_skip?(@entry)).to be_false
    end

    it "does not skip validation when there are no search criterions" do
      expect(@v.should_skip?(@entry)).to be_false
    end
  end
end