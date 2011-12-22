require 'spec_helper'

describe "power_of_attorneys/show.html.erb" do
  before(:each) do
    @power_of_attorney = assign(:power_of_attorney, stub_model(PowerOfAttorney,
      :company_id => 1,
      :uploaded_by => 1,
      :attachment_file_name => "Attachment File Name",
      :attachment_content_type => "Attachment Content Type",
      :attachment_file_size => 1
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(/1/)
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(/1/)
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(/Attachment File Name/)
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(/Attachment Content Type/)
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(/1/)
  end
end
