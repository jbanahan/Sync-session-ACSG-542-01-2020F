require 'spec_helper'

describe ApplicationHelper do

  describe 'field_value' do
    it "should output field's value" do
      ent = Factory(:entry,:entry_number=>'1234565478')
      User.current = Factory(:user)
      helper.field_value(ent,ModelField.find_by_uid(:ent_entry_num)).should == ent.entry_number
    end
  end

end
