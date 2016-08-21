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
      expect(found.value).to eq("abc")
      expect(found.id).not_to be_nil
    end
    it "should update an existing custom value" do
      @p.update_custom_value! @cd, "xyz"
      cv = CustomValue.first
      cv.value = 'abc'
      CustomValue.batch_write! [cv]
      expect(CustomValue.all.size).to eq(1)
      found = Product.find(@p.id).get_custom_value(@cd)
      expect(found.value).to eq("abc")
    end
    it "should fail if parent object is not saved" do
      expect {CustomValue.batch_write! [CustomValue.new(:custom_definition=>@cd,:customizable=>Product.new)]}.to raise_error
    end
    it "should fail if custom definition not set" do
      expect {CustomValue.batch_write! [CustomValue.new(:customizable=>@p)]}.to raise_error
    end
    it "should roll back all if one fails" do
      @p.update_custom_value! @cd, "xyz"
      cv = CustomValue.find_by_custom_definition_id @cd.id
      cv.value = 'abc'
      bad_cv = CustomValue.new(:customizable=>@p)
      expect {CustomValue.batch_write! [cv,bad_cv]}.to raise_error
      expect(CustomValue.all.size).to eq(1)
      expect(CustomValue.first.value).to eq('xyz')
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
      expect(@p.get_custom_value(@cd).value).to eq("abc")
      expect(@p.get_custom_value(cd2).value).to eq(2)
    end
    it "should touch parent's changed at if requested during batch_write" do
      ActiveRecord::Base.connection.execute "UPDATE products SET changed_at = \"2004-01-01\";"
      @p.reload
      expect(@p.changed_at).to be < 5.seconds.ago
      cv = CustomValue.new(:customizable=>@p,:custom_definition=>@cd)
      cv.value = 'abc'
      CustomValue.batch_write! [cv], true
      @p.reload
      expect(@p.changed_at).to be > 5.seconds.ago
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
      expect(CustomValue.first.value).to eq(";\" ABC")
    end
    it "should handle string" do
      @cd.update_attributes(:data_type=>'string')
      cv = CustomValue.new(:customizable=>@p,:custom_definition=>@cd)
      cv.value = 'abc'
      CustomValue.batch_write! [cv], true
      expect(@p.get_custom_value(@cd).value).to eq('abc')
    end
    it "should handle date" do
      @cd.update_attributes(:data_type=>'date')
      cv = CustomValue.new(:customizable=>@p,:custom_definition=>@cd)
      cv.value = Date.new(2012,4,21)
      CustomValue.batch_write! [cv], true
      expect(@p.get_custom_value(@cd).value).to eq(Date.new(2012,4,21))
    end
    it "should handle decimal" do
      @cd.update_attributes(:data_type=>'decimal')
      cv = CustomValue.new(:customizable=>@p,:custom_definition=>@cd)
      cv.value = 12.1
      CustomValue.batch_write! [cv], true
      expect(@p.get_custom_value(@cd).value).to eq(12.1)
    end
    it "should handle integer" do
      @cd.update_attributes(:data_type=>'integer')
      cv = CustomValue.new(:customizable=>@p,:custom_definition=>@cd)
      cv.value = 12.1
      CustomValue.batch_write! [cv], true
      expect(@p.get_custom_value(@cd).value).to eq(12)
    end
    it "should handle boolean" do
      @cd.update_attributes(:data_type=>'boolean')
      cv = CustomValue.new(:customizable=>@p,:custom_definition=>@cd)
      cv.value = true
      CustomValue.batch_write! [cv], true
      @p = Product.find @p.id
      expect(@p.get_custom_value(@cd).value).to be_truthy
      cv.value = false
      CustomValue.batch_write! [cv], true
      @p = Product.find @p.id
      expect(@p.get_custom_value(@cd).value).to be_falsey
    end
    it "should handle text" do
      @cd.update_attributes(:data_type=>'text')
      cv = CustomValue.new(:customizable=>@p,:custom_definition=>@cd)
      cv.value = 'aaaa'
      CustomValue.batch_write! [cv], true
      expect(@p.get_custom_value(@cd).value).to eq('aaaa')
    end
    it "should handle datetime" do
      t = 2.minutes.ago
      @cd.update_attributes(data_type:'datetime')
      cv = CustomValue.new(:customizable=>@p,:custom_definition=>@cd)
      cv.value = t
      CustomValue.batch_write! [cv], true
      g = @p.get_custom_value(@cd).value
      expect(g).to be_same_second_as t
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
      {"string"=>"string_value","boolean"=>"boolean_value","text"=>"text_value","date"=>"date_value","decimal"=>"decimal_value","integer"=>"integer_value","datetime"=>"datetime_value"}.each do |k,v|
        expect(CustomValue.new(:custom_definition=>CustomDefinition.new(:data_type=>k)).sql_field_name).to eq(v)
      end
    end
    it "should error if no custom definition" do
      expect {CustomValue.new.sql_field_name}.to raise_error "Cannot get sql field name without a custom definition"
    end
  end

  describe "value" do
    it "should round trip a datetime" do
      t = 2.minutes.ago
      cd = Factory(:custom_definition,:module_type=>"Product",:data_type=>"datetime")
      p = Factory(:product)
      p.update_custom_value!(cd,t)
      p.reload
      expect(p.get_custom_value(cd).value).to be_same_second_as t
    end

    it "handles user objects" do
      user = Factory(:user)
      user_def = Factory(:custom_definition, label: "Tested By", module_type: "Product", data_type: 'integer', is_user: true)
      cv = CustomValue.new custom_definition: user_def
      cv.value = user
      expect(cv.value).to eq user.id
    end

    it "handles address objects" do
      addr = Factory(:address)
      addr_def = Factory(:custom_definition, label: "Testing Address", module_type: "Product", data_type: 'integer', is_address: true)
      cv = CustomValue.new custom_definition: addr_def
      cv.value = addr
      expect(cv.value).to eq addr.id
    end
  end
end
