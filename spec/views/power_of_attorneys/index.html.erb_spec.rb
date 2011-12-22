require 'spec_helper'

describe "power_of_attorneys/index.html.erb" do
  before(:each) do
    assign(:power_of_attorneys, [
      stub_model(PowerOfAttorney,
        :company_id => 1,
        :uploaded_by => 1,
        :attachment_file_name => "Attachment File Name",
        :attachment_content_type => "Attachment Content Type",
        :attachment_file_size => 1
      ),
      stub_model(PowerOfAttorney,
        :company_id => 1,
        :uploaded_by => 1,
        :attachment_file_name => "Attachment File Name",
        :attachment_content_type => "Attachment Content Type",
        :attachment_file_size => 1
      )
    ])
  end

  it "renders a list of power_of_attorneys" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => 1.to_s, :count => 2
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => 1.to_s, :count => 2
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => "Attachment File Name".to_s, :count => 2
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => "Attachment Content Type".to_s, :count => 2
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => 1.to_s, :count => 2
  end
end
