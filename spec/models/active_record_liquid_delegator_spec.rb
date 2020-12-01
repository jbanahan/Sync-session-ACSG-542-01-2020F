describe ActiveRecordLiquidDelegator do
  let(:attachment) { FactoryBot(:attachment) }
  let(:liquid_attachment) {ActiveRecordLiquidDelegator.new(attachment)}

  it "creates a to_liquid method on a given object" do
    expect(liquid_attachment).to respond_to(:to_liquid)
  end

  it "allows an ActiveRecord object's attributes to be utilized directly in a liquid template" do
    expect(Liquid::Template.parse("Name: {{name.attached_file_name}}").render('name' => liquid_attachment)).to eq("Name: foo.bar")
  end
end
