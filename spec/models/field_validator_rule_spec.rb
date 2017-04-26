require 'spec_helper'

describe FieldValidatorRule do
  describe "max length" do
    before :each do
      @f = FieldValidatorRule.create!(:model_field_uid=>"ord_ord_num",:maximum_length=>3,:custom_message=>"1010")
    end
    it "should pass for valid values" do
      ["abc","ab","",nil].each do |v|
        expect(@f.validate_input(v)).to be_empty
      end
    end
    it "should fail for longer string" do
      expect(@f.validate_input("abcd").first).to eq(@f.custom_message)
    end
  end

  describe "view_groups" do
    it "returns a sorted list of view groups" do
      r = FieldValidatorRule.new can_view_groups: "Z\r\nY\nA"
      expect(r.view_groups).to eq ["A", "Y", "Z"]
    end
  end

  describe "edit_groups" do
    it "returns a sorted list of view groups" do
      r = FieldValidatorRule.new can_edit_groups: "Z\r\nY\nA"
      expect(r.edit_groups).to eq ["A", "Y", "Z"]
    end

    describe 'mass_edit_groups' do
      it "returns a sorted list of view groups" do
        r = FieldValidatorRule.new can_mass_edit_groups: "Z\r\nY\nA"
        expect(r.mass_edit_groups).to eq ["A", "Y", "Z"]
      end
    end
  end


  describe "string_hsh" do
    it "returns hash of values" do
      today = Date.today
      tomorrow = Date.today + 1
      fvr = FieldValidatorRule.create!(model_field_uid: :prod_uid, comment: "hi there", custom_message: "oh no!", xml_tag_name: "some-kinda-xml", 
                                       read_only: true, required: true, disabled: true, can_view_groups: "VIEWGROUP\nOTHERVIEWGROUP", 
                                       can_edit_groups: "EDITGROUP\nOTHEREDITGROUP", greater_than: 5, less_than: 10, more_than_ago: 5, 
                                       more_than_ago_uom: "day", less_than_from_now: 2, less_than_from_now_uom: "week", greater_than_date: Date.today, 
                                       less_than_date: tomorrow, minimum_length: 0, maximum_length: 10, starts_with: "fizz", ends_with: "buzz", 
                                       contains: "middle", one_of: "us\nthem")
      hsh = fvr.string_hsh
      #general
      expect(hsh[:comment]).to eq "Comment: hi there"
      expect(hsh[:custom_message]).to eq "Custom Error Message: oh no!"
      expect(hsh[:xml_tag_name]).to eq "Custom XML Tag: some-kinda-xml"
      expect(hsh[:read_only]).to eq "Read Only: true"
      expect(hsh[:required]).to eq "Required: true"
      expect(hsh[:disabled]).to eq "Disabled For All Users: true"
      expect(hsh[:can_view_groups]).to eq "Groups That Can View Field: VIEWGROUP, OTHERVIEWGROUP"
      expect(hsh[:can_edit_groups]).to eq "Groups That Can Edit Field: EDITGROUP, OTHEREDITGROUP"
      #decimal/integer
      expect(hsh[:greater_than]).to eq "Greater Than 5.0"
      expect(hsh[:less_than]).to eq "Less Than 10.0"
      #date/datetime
      expect(hsh[:more_than_ago]).to eq "More Than 5 days ago"
      expect(hsh[:less_than_from_now]).to eq "Less Than 2 weeks from now"
      expect(hsh[:greater_than_date]).to eq "After #{today.to_s}"
      expect(hsh[:less_than_date]).to eq "Before #{tomorrow.to_s}"
      #string/text
      expect(hsh[:minimum_length]).to eq "Minimum Length: 0"
      expect(hsh[:maximum_length]).to eq "Maximum Length: 10"
      expect(hsh[:starts_with]).to eq "Starts With 'fizz'"
      expect(hsh[:ends_with]).to eq "Ends With 'buzz'"
      expect(hsh[:contains]).to eq "Contains 'middle'"
      expect(hsh[:one_of]).to eq "Is One Of: us, them"
    end

    it "omits missing values" do
      fvr = FieldValidatorRule.create!(model_field_uid: :prod_ent_type, comment: "hi there")
      expect(fvr.string_hsh).to eq({comment: "Comment: hi there"})
    end
  
  end
end
