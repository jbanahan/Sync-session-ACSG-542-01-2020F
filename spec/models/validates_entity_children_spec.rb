describe ValidatesEntityChildren do

  let (:entry) {
    entry = Factory(:entry)
    inv = Factory(:commercial_invoice, entry: entry)
    line = Factory(:commercial_invoice_line, commercial_invoice: inv, po_number: "ABC")
    line_2 = Factory(:commercial_invoice_line, commercial_invoice: inv, po_number: "DEF")
    entry
  }

  # Create a simple class that validates a commercial invoice line to test the module
  class FakeValidationRule < BusinessValidationRule
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

    def run_child_validation a
      raise "Mock Me"
    end
  end

  subject { FakeValidationRule.new }

  describe "run_validation" do
    it "validates child objects" do
      expect(subject).to receive(:run_child_validation).with(entry.commercial_invoice_lines.first).and_return ""
      expect(subject).to receive(:run_child_validation).with(entry.commercial_invoice_lines.second).and_return ""
      expect(subject.run_validation(entry)).to be_nil
    end

    it "returns errors for each object" do
      expect(subject).to receive(:run_child_validation).with(entry.commercial_invoice_lines.first).and_return "Error 1"
      expect(subject).to receive(:run_child_validation).with(entry.commercial_invoice_lines.second).and_return "Error 2"
      expect(subject.run_validation(entry)).to eq "Error 1\nError 2"
    end

    it "allows multiple errors returned for a validation object" do
      expect(subject).to receive(:run_child_validation).with(entry.commercial_invoice_lines.first).and_return ["Error 1", "Error 2"]
      expect(subject).to receive(:run_child_validation).with(entry.commercial_invoice_lines.second).and_return "Error 3"
      expect(subject.run_validation(entry)).to eq "Error 1\nError 2\nError 3"
    end

    it "skip lines that don't match child level search criteria" do
      subject.search_criterions.build model_field_uid:'cil_po_number', operator:'eq', value:'ABC'
      expect(subject).to receive(:run_child_validation).with(entry.commercial_invoice_lines.first).and_return "Error 1"

      expect(subject.run_validation(entry)).to eq "Error 1"
    end

    it "skip lines that don't match header level search criteria" do
      subject.search_criterions.build model_field_uid:'ent_entry_num', operator:'eq', value:'123'
      expect(subject).not_to receive(:run_child_validation)

      expect(subject.run_validation(entry)).to be_nil
    end

    it "doesn't validated children if stop is called" do
      # Since we're calling stop, the second line shouldn't be evaluated.
      expect(subject).to receive(:run_child_validation).with(entry.commercial_invoice_lines.first) do |param|
        subject.stop_validation
        "Error"
      end

      expect(subject.run_validation(entry)).to eq "Error"
      # This is peeking below the covers, but I want to make sure the stopped flag is destroyed after it's needed
      # so it's definitely not left around in case the rule object is re-used
      expect(subject.instance_variables).not_to include(:subjectalidation_stopped)
    end

    context "with setup_validation implemented" do

      class FakeValidationRuleWithSetup < FakeValidationRule
        def setup_validation
          raise "Mock Me"
        end
      end

      subject { FakeValidationRuleWithSetup.new }

      it "calls setup_validation if defined" do
        expect(subject).to receive(:setup_validation)
        expect(subject).to receive(:run_child_validation).exactly(2).times
        expect(subject.run_validation(entry)).to be_nil
      end
    end

  end

  describe "should_skip?" do
    it "skips validation when no search criterion matches" do
      subject.search_criterions.build model_field_uid:'ent_entry_num', operator:'eq', value:'123'
      expect(subject.should_skip?(entry)).to be_truthy
    end

    it "does not skip validation when search criterion matches header" do
      subject.search_criterions.build model_field_uid:'ent_entry_num', operator:'null'
      expect(subject.should_skip?(entry)).to be_falsey
    end

    it "does not skip validation when search criterion matches a single child" do
      subject.search_criterions.build model_field_uid:'cil_po_number', operator:'eq', value:'ABC'
      expect(subject.should_skip?(entry)).to be_falsey
    end

    it "does not skip validation when there are no search criterions" do
      expect(subject.should_skip?(entry)).to be_falsey
    end
  end
end