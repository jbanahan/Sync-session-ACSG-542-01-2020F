require 'spec_helper'

describe "power_of_attorneys/edit.html.erb" do
  before(:each) do
    @power_of_attorney = assign(:power_of_attorney, stub_model(PowerOfAttorney,
      :company_id => 1,
      :uploaded_by => 1,
      :attachment_file_name => "MyString",
      :attachment_content_type => "MyString",
      :attachment_file_size => 1
    ))
  end

  it "renders the edit power_of_attorney form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form", :action => power_of_attorneys_path(@power_of_attorney), :method => "post" do
      assert_select "input#power_of_attorney_company_id", :name => "power_of_attorney[company_id]"
      assert_select "input#power_of_attorney_uploaded_by", :name => "power_of_attorney[uploaded_by]"
      assert_select "input#power_of_attorney_attachment_file_name", :name => "power_of_attorney[attachment_file_name]"
      assert_select "input#power_of_attorney_attachment_content_type", :name => "power_of_attorney[attachment_content_type]"
      assert_select "input#power_of_attorney_attachment_file_size", :name => "power_of_attorney[attachment_file_size]"
    end
  end
end
