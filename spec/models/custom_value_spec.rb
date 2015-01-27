require 'spec_helper'

describe CustomValue do
  describe :batch_write! do
    before :each do
      @cd = Factory(:custom_definition,:module_type=>"Product",:data_type=>"string")
      @p = Factory(:product)
    end
    it "should insert a new custom value" do
      cv = CustomValue.new(:custom_definition=>@cd,:customizable=>@p)
      cv.value = "abc"
      CustomValue.batch_write! [cv]
      found = @p.get_custom_value @cd
      found.value.should == "abc"
      found.id.should_not be_nil
    end
    it "should update an existing custom value" do
      @p.update_custom_value! @cd, "xyz"
      cv = CustomValue.first
      cv.value = 'abc'
      CustomValue.batch_write! [cv]
      CustomValue.all.should have(1).value
      found = Product.find(@p.id).get_custom_value(@cd)
      found.value.should == "abc"
    end
    it "should fail if parent object is not saved" do
      lambda {CustomValue.batch_write! [CustomValue.new(:custom_definition=>@cd,:customizable=>Product.new)]}.should raise_error
    end
    it "should fail if custom definition not set" do
      lambda {CustomValue.batch_write! [CustomValue.new(:customizable=>@p)]}.should raise_error
    end
    it "should roll back all if one fails" do
      @p.update_custom_value! @cd, "xyz"
      cv = CustomValue.find_by_custom_definition_id @cd.id
      cv.value = 'abc'
      bad_cv = CustomValue.new(:customizable=>@p)
      lambda {CustomValue.batch_write! [cv,bad_cv]}.should raise_error
      CustomValue.all.should have(1).value
      CustomValue.first.value.should == 'xyz'
    end
    it "should insert and update values" do
      cd2 = Factory(:custom_definition,:module_type=>"Product",:data_type=>"integer")
      @p.update_custom_value! @cd, "xyz"
      cv = CustomValue.find_by_custom_definition_id @cd.id
      cv.value = 'abc'
      cv2 = CustomValue.new(:customizable=>@p,:custom_definition=>cd2)
      cv2.value = 2
      CustomValue.batch_write! [cv,cv2]
      @p.reload
      @p.get_custom_value(@cd).value.should == "abc"
      @p.get_custom_value(cd2).value.should == 2
    end
    it "should touch parent's changed at if requested during batch_write" do
      ActiveRecord::Base.connection.execute "UPDATE products SET changed_at = \"2004-01-01\";"
      @p.reload
      @p.changed_at.should < 5.seconds.ago
      cv = CustomValue.new(:customizable=>@p,:custom_definition=>@cd)
      cv.value = 'abc'
      CustomValue.batch_write! [cv], true
      @p.reload
      @p.changed_at.should > 5.seconds.ago
    end
    it "should touch parent's changed at if new custom value added" do
      @p.update_custom_value! @cd, 'abc'
      @p.reload
      expect(@p.changed_at).to be > 1.minute.ago
    end
    it "should touch parent's changed at if a custom value is updated" do
      # Changed At will not be set if it's been less than a minutes since it was previously set
      @p.update_custom_value! @cd, 'abc'
      @p.reload

      @p.update_attributes! changed_at: 1.day.ago
      @p.reload

      @p.update_custom_value! @cd, 'def'
      @p.reload
      expect(@p.changed_at).to be > 1.minute.ago
    end
    it "should not touch parent changed at if changed at is less than 1 minute ago" do
      @p.update_custom_value! @cd, 'abc'
      @p.reload
      ca = @p.changed_at

      @p.update_custom_value! @cd, 'def'
      @p.reload
      expect(@p.changed_at).to eq ca
    end
    it "should not touch parent's changed at if no custom value attributes have changed" do
      @p.update_custom_value! @cd, 'abc'
      @p.reload
      changed_at = @p.changed_at

      # Because changed_at is not updated if it's less than a minute old, update
      # it to older than that via update_column, otherwise callbacks are invoked 
      # and changed_at is updated to now
      yesterday = 1.day.ago
      @p.update_column :changed_at, yesterday
      @p.reload
      # The save update strips some precision on the time, so just pull the value
      # for comparison after reloading the product
      yesterday = @p.changed_at
      @p.update_custom_value! @cd, 'abc'
      @p.reload
      expect(@p.changed_at).to eq yesterday

      cv = @p.custom_values.first
      cv.save!
      @p.reload
      expect(@p.changed_at).to eq yesterday
    end
    it "should sanitize parameters" do
      cv = CustomValue.new(:customizable=>@p,:custom_definition=>@cd)
      cv.value = ';" ABC'
      CustomValue.batch_write! [cv], true
      CustomValue.first.value.should == ";\" ABC"
    end
    it "should handle string" do
      @cd.update_attributes(:data_type=>'string')
      cv = CustomValue.new(:customizable=>@p,:custom_definition=>@cd)
      cv.value = 'abc'
      CustomValue.batch_write! [cv], true
      @p.get_custom_value(@cd).value.should == 'abc'
    end
    it "should handle date" do
      @cd.update_attributes(:data_type=>'date')
      cv = CustomValue.new(:customizable=>@p,:custom_definition=>@cd)
      cv.value = Date.new(2012,4,21)
      CustomValue.batch_write! [cv], true
      @p.get_custom_value(@cd).value.should == Date.new(2012,4,21)
    end
    it "should handle decimal" do
      @cd.update_attributes(:data_type=>'decimal')
      cv = CustomValue.new(:customizable=>@p,:custom_definition=>@cd)
      cv.value = 12.1
      CustomValue.batch_write! [cv], true
      @p.get_custom_value(@cd).value.should == 12.1
    end
    it "should handle integer" do
      @cd.update_attributes(:data_type=>'integer')
      cv = CustomValue.new(:customizable=>@p,:custom_definition=>@cd)
      cv.value = 12.1
      CustomValue.batch_write! [cv], true
      @p.get_custom_value(@cd).value.should == 12
    end
    it "should handle boolean" do
      @cd.update_attributes(:data_type=>'boolean')
      cv = CustomValue.new(:customizable=>@p,:custom_definition=>@cd)
      cv.value = true
      CustomValue.batch_write! [cv], true
      @p = Product.find @p.id
      @p.get_custom_value(@cd).value.should be_true
      cv.value = false
      CustomValue.batch_write! [cv], true
      @p = Product.find @p.id
      @p.get_custom_value(@cd).value.should be_false
    end
    it "should handle text" do
      @cd.update_attributes(:data_type=>'text')
      cv = CustomValue.new(:customizable=>@p,:custom_definition=>@cd)
      cv.value = 'aaaa'
      CustomValue.batch_write! [cv], true
      @p.get_custom_value(@cd).value.should == 'aaaa'
    end

    it "should skip nil values" do
      @cd.update_attributes(:data_type=>'text')
      cv = CustomValue.new(:customizable=>@p,:custom_definition=>@cd)
      cv.value = nil
      CustomValue.batch_write! [cv], false
      expect(@p.get_custom_value(@cd).value).to be_nil
    end
  end

  describe "sql_field_name" do
    it "should handle data types" do
      {"string"=>"string_value","boolean"=>"boolean_value","text"=>"text_value","date"=>"date_value","decimal"=>"decimal_value","integer"=>"integer_value"}.each do |k,v|
        CustomValue.new(:custom_definition=>CustomDefinition.new(:data_type=>k)).sql_field_name.should == v
      end
    end
    it "should error if no custom definition" do
      lambda {CustomValue.new.sql_field_name}.should raise_error "Cannot get sql field name without a custom definition"
    end
  end
end
