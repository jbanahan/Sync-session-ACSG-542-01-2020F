describe OpenChain::TemplateUtil do

  subject { described_class }

  describe "interpolate_liquid_string" do
    it "accepts a template string and variables and safely interpolates" do
      expect(subject.interpolate_liquid_string('hi {{name}}', {'name' => 'tobi'})).to eq 'hi tobi'
    end

    it "strips whitespace" do
      expect(subject.interpolate_liquid_string('  hi {{name}}   ', {'name' => 'tobi'})).to eq 'hi tobi'
    end

    it "raises an exception if there is syntax problem" do
      expect {subject.interpolate_liquid_string('hi {{name', {'name' => 'tobi'})}.to raise_error(Liquid::SyntaxError)
    end

    it "raises an exception if there is a missing variable" do
      expect {subject.interpolate_liquid_string('hi {{nope}}', {'name' => 'tobi'})}.to raise_error(Liquid::UndefinedVariable)
    end

    it "raises an exception if there is a missing filter" do
      expect {subject.interpolate_liquid_string('hi {{name | nope}}', {'name' => 'tobi'})}.to raise_error(Liquid::UndefinedFilter)
    end
  end
end
