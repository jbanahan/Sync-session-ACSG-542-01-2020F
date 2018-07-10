describe CustomDefinition do

  describe "generate_cdef_uid" do
    subject { described_class }
    let (:custom_definition) { CustomDefinition.new module_type: "Order", label: "Some Field"}

    it "generates a cdef_uid from the module and label" do
      expect(subject.generate_cdef_uid custom_definition).to eq "ord_some_field"
    end

    it "converts non-word chars to underscore, squeezing consecutive underscores together" do
      custom_definition.label = "Hey, You Guys!"
      expect(subject.generate_cdef_uid custom_definition).to eq "ord_hey_you_guys"
    end
  end
end