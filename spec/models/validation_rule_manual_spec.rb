require 'spec_helper'

describe ValidationRuleManual do
  describe :run_validation do
    it "should always return manual check needed" do
      expect(described_class.new.run_validation(Entry.new)).to eq "Manual review required."
    end
  end
end
