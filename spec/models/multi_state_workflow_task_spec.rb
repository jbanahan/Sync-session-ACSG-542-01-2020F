require 'spec_helper'

describe MultiStateWorkflowTask do
  describe :options do
    it "should serialize" do
      m = described_class.new
      m.options = ['a','b']
      expect(m.state_options_list).to eq "a\nb"
      expect(m.options).to eq ['a','b']
    end
  end
end
