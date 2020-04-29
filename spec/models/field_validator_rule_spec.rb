describe FieldValidatorRule do
  describe "max length" do
    before :each do
      @f = FieldValidatorRule.create!(:model_field_uid=>"ord_ord_num", :maximum_length=>3, :custom_message=>"1010")
    end
    it "should pass for valid values" do
      ["abc", "ab", "", nil].each do |v|
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
      fvr = FieldValidatorRule.new(model_field_uid: :prod_uid, comment: "hi there", custom_message: "oh no!", xml_tag_name: "some-kinda-xml",
                                       read_only: true, required: true, disabled: true, can_view_groups: "VIEWGROUP\nOTHERVIEWGROUP",
                                       can_edit_groups: "EDITGROUP\nOTHEREDITGROUP", can_mass_edit_groups: "Test\nTest2", greater_than: 5, less_than: 10, more_than_ago: 5,
                                       more_than_ago_uom: "day", less_than_from_now: 2, less_than_from_now_uom: "week", greater_than_date: Date.today,
                                       less_than_date: tomorrow, minimum_length: 0, maximum_length: 10, starts_with: "fizz", ends_with: "buzz",
                                       contains: "middle", one_of: "us\nthem", mass_edit: true, allow_everyone_to_view: true)
      hsh = fvr.string_hsh
      # general
      expect(hsh[:comment]).to eq "Comment: hi there"
      expect(hsh[:custom_message]).to eq "Custom Error Message: oh no!"
      expect(hsh[:xml_tag_name]).to eq "Custom XML Tag: some-kinda-xml"
      expect(hsh[:read_only]).to eq "Read Only: true"
      expect(hsh[:required]).to eq "Required: true"
      expect(hsh[:disabled]).to eq "Disabled For All Users: true"
      expect(hsh[:allow_everyone_to_view]).to eq "Allow Everyone To View: true"
      expect(hsh[:can_view_groups]).to eq "Groups That Can View Field: VIEWGROUP, OTHERVIEWGROUP"
      expect(hsh[:can_edit_groups]).to eq "Groups That Can Edit Field: EDITGROUP, OTHEREDITGROUP"
      expect(hsh[:can_mass_edit_groups]).to eq "Groups That Can Mass Edit Field: Test, Test2"
      # decimal/integer
      expect(hsh[:greater_than]).to eq "Greater Than 5.0"
      expect(hsh[:less_than]).to eq "Less Than 10.0"
      # date/datetime
      expect(hsh[:more_than_ago]).to eq "More Than 5 days ago"
      expect(hsh[:less_than_from_now]).to eq "Less Than 2 weeks from now"
      expect(hsh[:greater_than_date]).to eq "After #{today.to_s}"
      expect(hsh[:less_than_date]).to eq "Before #{tomorrow.to_s}"
      # string/text
      expect(hsh[:minimum_length]).to eq "Minimum Length: 0"
      expect(hsh[:maximum_length]).to eq "Maximum Length: 10"
      expect(hsh[:starts_with]).to eq "Starts With 'fizz'"
      expect(hsh[:ends_with]).to eq "Ends With 'buzz'"
      expect(hsh[:contains]).to eq "Contains 'middle'"
      expect(hsh[:one_of]).to eq "Is One Of: us, them"
      expect(hsh[:mass_edit]).to eq "Mass Editable"
    end

    it "omits missing values" do
      fvr = FieldValidatorRule.create!(model_field_uid: :prod_ent_type, comment: "hi there")
      expect(fvr.string_hsh).to eq({comment: "Comment: hi there"})
    end
  end

  describe "requires_remote_validation?" do
    it "does not require remote validation by default" do
      expect(subject.requires_remote_validation?).to eq false
    end

    it "does not require remote validate if all non-validation attributes have values" do
      subject.allow_everyone_to_view = true
      subject.can_edit_groups = "GROUP"
      subject.can_view_groups = "GROUP"
      subject.can_mass_edit_groups = "GROUP"
      subject.comment = "COMMENT"
      subject.created_at = Time.zone.now
      subject.updated_at = Time.zone.now
      subject.custom_message = "Message"
      subject.mass_edit = true
      subject.xml_tag_name = "TAG"
      subject.id = 1

      expect(subject.requires_remote_validation?).to eq false
    end

    context "with remote validation required" do
      after :each do
        expect(subject.requires_remote_validation?).to eq true
      end

      it "requires remote validation if field is required" do
        subject.required = true
      end

      it "requires remote validation if greater_than is present" do
        subject.greater_than = 1
      end

      it "requires remote validation if less_than is present" do
        subject.greater_than = 1
      end

      it "requires remote validate if more_than_ago is present" do
        subject.more_than_ago = 1
      end

      it "requires remote validate if less_than_from_now is present" do
        subject.less_than_from_now = 1
      end

      it "requires remote validate if greater_than_date is present" do
        subject.greater_than_date = Date.new(2017, 8, 1)
      end

      it "requires remote validate if less_than_date is present" do
        subject.less_than_date = Date.new(2017, 8, 1)
      end

      it "requires remote validate if regex is present" do
        subject.regex = "ABC"
      end

      it "requires remote validate if starts_with is present" do
        subject.starts_with = "ABC"
      end

      it "requires remote validate if ends_with is present" do
        subject.ends_with = "ABC"
      end

      it "requires remote validate if contains is present" do
        subject.contains = "ABC"
      end

      it "requires remote validate if one_of is present" do
        subject.one_of = "ABC"
      end

      it "requires remote validate if minimum_length is present" do
        subject.minimum_length = 1
      end

      it "requires remote validate if maximum_length is present" do
        subject.maximum_length = 1
      end
    end
  end
end
