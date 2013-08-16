require 'spec_helper'

describe ApplicationHelper do

  describe 'field_value' do
    it "should output field's value" do
      ent = Factory(:entry,:entry_number=>'1234565478')
      User.current = Factory(:user)
      helper.field_value(ent,ModelField.find_by_uid(:ent_entry_num)).should == ent.entry_number
    end

    it "should strip trailing zeros off non-currency decimal values" do
      # This value should also be rounded to 5 decimal places
      # Use .999999 which then rounds to 1.00000 and should output as 1
      ent = Factory(:entry,:total_units => BigDecimal.new(".999999"))
      User.current = Factory(:user)

      helper.field_value(ent, ModelField.find_by_uid(:ent_total_units)).should == "1"
    end

    it "should not strip trailing decimals from currency and round two 2 decimal places (USD)" do
      ent = Factory(:entry,:total_fees => BigDecimal.new("999.995"))
      User.current = Factory(:user)

      # Uses $ for fields marked as US currency
      helper.field_value(ent, ModelField.find_by_uid(:ent_total_fees)).should == "$1,000.00"
    end

    it "should not strip trailing decimals from currency and round two 2 decimal places" do
      # Uses $ for fields marked as US currency
      inv = Factory(:commercial_invoice, :invoice_value_foreign=>BigDecimal.new("999.995"))
      User.current = Factory(:user)

      helper.field_value(inv, ModelField.find_by_uid(:ci_invoice_value_foreign)).should == "1,000.00"
      inv.invoice_value_foreign = BigDecimal.new("-999.995")
      helper.field_value(inv, ModelField.find_by_uid(:ci_invoice_value_foreign)).should == "-1,000.00"
    end
  end

end
