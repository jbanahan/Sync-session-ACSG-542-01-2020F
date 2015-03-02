require 'spec_helper'

describe "CustomFieldSupport" do
  describe "update_custom_value" do
    before :each do
      @cd = CustomDefinition.create!(:module_type=>"Shipment",:label=>"CX",:data_type=>"string") 
      @s = Factory(:shipment)
      @s.update_custom_value!(@cd,"x")
    end
    it 'should update a new custom value' do
      CustomValue.find_by_custom_definition_id_and_string_value(@cd.id,"x").customizable.should == @s
    end
    it 'should update an existing custom value' do
      @s.update_custom_value!(@cd,"y")
      CustomValue.find_by_custom_definition_id_and_string_value(@cd.id,"y").customizable.should == @s
    end
    it 'should update with a custom_value_id' do
      @s.update_custom_value!(@cd.id,"y")
      CustomValue.find_by_custom_definition_id_and_string_value(@cd.id,"y").customizable.should == @s
    end
  end
  describe :get_custom_value do
    it "should get the same custom value object twice without saving" do
      cd = Factory(:custom_definition,:module_type=>'Product')
      p = Factory(:product)
      cv = p.get_custom_value cd
      p.get_custom_value(cd).should equal cv

    end
  end

  describe :freeze_custom_values do
    it "should freeze cached values and no longer hit database" do
      cd = Factory(:custom_definition,:module_type=>'Product',data_type:'string')
      cd2 = Factory(:custom_definition,:module_type=>'Product',data_type:'string')
      p = Factory(:product)
      p.update_custom_value!(cd.id,'y')
      fresh_p = Product.includes(:custom_values).where(id:p.id).first
      fresh_p.freeze_custom_values #now that it's frozen, it's values shouldn't change
      p.update_custom_value!(cd2.id,'other')
      p.update_custom_value!(cd.id,'n')
      expect(p.get_custom_value(cd).value).to eq 'n'
      expect(p.get_custom_value(cd2).value).to eq 'other'

      expect(fresh_p.get_custom_value(cd).value).to eq 'y'
      expect(fresh_p.get_custom_value(cd2).id).to be_nil
      expect(fresh_p.get_custom_value(cd2).value).to be_nil
    end
  end

  describe :freeze_all_custom_values_including_children do
    it "calls freeze_custom_values on all levels of the obj" do
      p = Product.new
      c = Classification.new
      c2 = Classification.new
      t = TariffRecord.new
      t2 = TariffRecord.new

      c.tariff_records << t
      c.tariff_records << t2
      p.classifications << c
      p.classifications << c2

      p.should_receive(:freeze_custom_values)
      c.should_receive(:freeze_custom_values)
      c2.should_receive(:freeze_custom_values)
      t.should_receive(:freeze_custom_values)
      t2.should_receive(:freeze_custom_values)
      p.freeze_all_custom_values_including_children
    end
  end

  describe "find_and_set_custom_value" do
    it "finds a custom value object in the custom_values relation and sets it to the given value" do
      cd = Factory(:custom_definition,:module_type=>'Product',data_type:'string')
      p = Factory(:product)
      p.update_custom_value! cd, "VALUE"

      cv = p.find_and_set_custom_value cd, "OTHER VALUE"

      expect(cv.changed?).to be_true
      expect(cv.value).to eq "OTHER VALUE"
      p.save!
      expect(cv.changed?).to be_false

      p.reload
      p.custom_values.reload
      expect(p.custom_values.first).to be_persisted
      expect(p.get_custom_value(cd).value).to eq "OTHER VALUE"
    end

    it "creates a new custom value if no existing one is found" do
      cd = Factory(:custom_definition,:module_type=>'Product',data_type:'string')
      p = Product.new unique_identifier: "ABC"

      cv = p.find_and_set_custom_value cd, "VALUE"
      expect(cv.changed?).to be_true
      expect(cv).not_to be_persisted
      p.save!

      p.reload
      p.custom_values.reload
      expect(p.custom_values.first).to be_persisted
      expect(p.get_custom_value(cd).value).to eq "VALUE"
    end
  end
end
