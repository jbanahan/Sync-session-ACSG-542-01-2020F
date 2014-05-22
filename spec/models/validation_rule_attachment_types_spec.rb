require 'spec_helper'

describe ValidationRuleAttachmentTypes do

  it "should return nil if all attachments are present" do
    json = {model_field_uid: :ent_cust_name, regex: "ABC", attachment_types: ["one"]}.to_json
    vr = ValidationRuleAttachmentTypes.create!(rule_attributes_json:json)
    att = Factory(:attachment, attachment_type: "one")
    e = Factory(:entry, attachments: [att])

    # nil means no types were missing
    vr.run_validation(e).should be_nil
  end

  it "should also return nil if the attachment type is a string rather than a list" do
    json = {model_field_uid: :ent_cust_name, regex: "ABC", attachment_types: "one"}.to_json
    vr = ValidationRuleAttachmentTypes.create!(rule_attributes_json:json)
    att = Factory(:attachment, attachment_type: "one")
    e = Factory(:entry, attachments: [att])

    # nil means no types were missing
    vr.run_validation(e).should be_nil
  end
  
  it "should return message indicating missing attachment type when appropriate" do
    json = {model_field_uid: :ent_cust_name, regex: "ABC", attachment_types: ["one", "two"]}.to_json
    vr = ValidationRuleAttachmentTypes.create!(rule_attributes_json:json)
    att = Factory(:attachment, attachment_type: "one")
    e = Factory(:entry, attachments: [att])

    vr.run_validation(e).should == "Missing attachment type two."
  end

  it "should raise error indicated attachment types were not specified when appropriate" do
    json = {model_field_uid: :ent_cust_name, regex: "ABC"}.to_json
    vr = ValidationRuleAttachmentTypes.create!(rule_attributes_json:json)
    e = Factory(:entry)

    expect { vr.run_validation(e) }.to raise_error(RuntimeError, "No attachment types were specified.")
  end

end