require 'spec_helper'

describe "CustomFieldSupport" do
  describe "update_custom_value" do
    before :each do
      @cd = CustomDefinition.create!(:module_type=>"Shipment",:label=>"CX",:data_type=>"string") 
      @s = Factory(:shipment)
      @s.update_custom_value!(@cd,"x")
    end
    it 'should update a new custom value' do
      expect(CustomValue.find_by_custom_definition_id_and_string_value(@cd.id,"x").customizable).to eq(@s)
    end
    it 'should update an existing custom value' do
      @s.update_custom_value!(@cd,"y")
      expect(CustomValue.find_by_custom_definition_id_and_string_value(@cd.id,"y").customizable).to eq(@s)
    end
    it 'should update with a custom_value_id' do
      @s.update_custom_value!(@cd.id,"y")
      expect(CustomValue.find_by_custom_definition_id_and_string_value(@cd.id,"y").customizable).to eq(@s)
    end
  end
  describe "get_custom_value" do
    it "should get the same custom value object twice without saving" do
      cd = Factory(:custom_definition,:module_type=>'Product')
      p = Factory(:product)
      cv = p.get_custom_value cd
      expect(p.get_custom_value(cd)).to equal cv
    end
  end

  describe "custom_value" do
    let (:custom_def) { Factory(:custom_definition,:module_type=>'Product',data_type:'string') }
    let (:obj) { Factory(:product) }

    it "retrieves a custom value" do
      obj.custom_values.create! custom_definition: custom_def, string_value: "Testing"
      expect(obj.custom_value(custom_def)).to eq "Testing"
    end

    it "returns nil if no custom value exists for the given definition" do
      expect(obj.custom_value(custom_def)).to be_nil
    end

    it "does not use internal custom value caches" do
      cv = obj.custom_values.create! custom_definition: custom_def, string_value: "Testing"
      obj.load_custom_values

      other_cv = obj.custom_values.reload.first
      other_cv.value = "Test2"
      other_cv.save!

      expect(obj.custom_value(custom_def)).to eq "Test2"
    end
  end

  describe "freeze_custom_values" do
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

  describe "freeze_all_custom_values_including_children" do
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

      expect(p).to receive(:freeze_custom_values)
      expect(c).to receive(:freeze_custom_values)
      expect(c2).to receive(:freeze_custom_values)
      expect(t).to receive(:freeze_custom_values)
      expect(t2).to receive(:freeze_custom_values)
      p.freeze_all_custom_values_including_children
    end
  end

  describe "find_and_set_custom_value" do
    it "finds a custom value object in the custom_values relation and sets it to the given value" do
      cd = Factory(:custom_definition,:module_type=>'Product',data_type:'string')
      p = Factory(:product)
      p.update_custom_value! cd, "VALUE"

      cv = p.find_and_set_custom_value cd, "OTHER VALUE"

      expect(cv.changed?).to be_truthy
      expect(cv.value).to eq "OTHER VALUE"
      p.save!
      expect(cv.changed?).to be_falsey

      p.reload
      p.custom_values.reload
      expect(p.custom_values.first).to be_persisted
      expect(p.get_custom_value(cd).value).to eq "OTHER VALUE"
    end

    it "creates a new custom value if no existing one is found" do
      cd = Factory(:custom_definition,:module_type=>'Product',data_type:'string')
      p = Product.new unique_identifier: "ABC"

      cv = p.find_and_set_custom_value cd, "VALUE"
      expect(cv.changed?).to be_truthy
      expect(cv).not_to be_persisted
      p.save!

      p.reload
      p.custom_values.reload
      expect(p.custom_values.first).to be_persisted
      expect(p.get_custom_value(cd).value).to eq "VALUE"
    end
  end
end
