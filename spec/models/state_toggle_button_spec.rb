require 'spec_helper'

describe StateToggleButton do
  describe :for_core_object_user do
    it "should find from same core_module" do
      btn = Factory(:state_toggle_button,module_type:'Company')
      Factory(:state_toggle_button,module_type:'Order') #don't find
      c = Factory(:company)
      u = Factory(:user)
      expect(described_class.for_core_object_user(c,u)).to eq [btn]
    end
    it "should return consistent results twice (testing internal cache)" do
      btn = Factory(:state_toggle_button,module_type:'Company')
      Factory(:state_toggle_button,module_type:'Order') #don't find
      c = Factory(:company)
      u = Factory(:user)
      expect(described_class.for_core_object_user(c,u)).to eq [btn]
      expect(described_class.for_core_object_user(c,u)).to eq [btn]
    end
    it "should filter by search_criterion" do
      btn = Factory(:state_toggle_button,module_type:'Company')
      btn.search_criterions.create!(model_field_uid:'cmp_sys_code',operator:'eq',value:'ABC')
      btn2 = Factory(:state_toggle_button,module_type:'Company')
      btn2.search_criterions.create!(model_field_uid:'cmp_sys_code',operator:'eq',value:'DEF')

      c = Factory(:company,system_code:'ABC')
      u = Factory(:user)

      expect(described_class.for_core_object_user(c,u)).to eq [btn]
    end
    it "should not find if user not in any permission group" do
      Factory(:state_toggle_button,module_type:'Company',permission_group_system_codes:"GRPA\nGRPB\nGRPC")
      c = Factory(:company)
      u = Factory(:user)
      expect(described_class.for_core_object_user(c,u)).to eq []
    end
    it "should find if user in a permission group" do
      btn = Factory(:state_toggle_button,module_type:'Company',permission_group_system_codes:"GRPA\nGRPB\nGRPC")
      c = Factory(:company)
      u = Factory(:user)
      g = Group.use_system_group 'GRPB'
      u.groups << g
      expect(described_class.for_core_object_user(c,u)).to eq [btn]
    end
  end

  describe :toggle! do
    it "should set the date and user_id fields" do
      btn = Factory(:state_toggle_button,module_type:'Shipment',date_attribute:'canceled_date',user_attribute:'canceled_by')
      s = Factory(:shipment)
      u = Factory(:user)

      s.should_receive(:create_snapshot_with_async_option).with(false,u)
      btn.toggle! s, u

      s.reload
      expect(s.canceled_date).to_not be_nil
      expect(s.canceled_by).to eq u
    end
    it "should clear the date and user_id fields" do
      btn = Factory(:state_toggle_button,module_type:'Shipment',date_attribute:'canceled_date',user_attribute:'canceled_by')
      u = Factory(:user)
      s = Factory(:shipment,canceled_date:1.day.ago,canceled_by:u)

      s.should_receive(:create_snapshot_with_async_option).with(false,u)
      btn.toggle! s, u

      s.reload
      expect(s.canceled_date).to be_nil
      expect(s.canceled_by).to be_nil
    end
    it "should prefer date when fields are in opposite state" do
      btn = Factory(:state_toggle_button,module_type:'Shipment',date_attribute:'canceled_date',user_attribute:'canceled_by')
      u = Factory(:user)
      s = Factory(:shipment,canceled_date:1.day.ago)

      s.should_receive(:create_snapshot_with_async_option).with(false,u)
      btn.toggle! s, u

      s.reload
      expect(s.canceled_date).to be_nil
      expect(s.canceled_by).to be_nil
    end
    it "should set custom value fields" do
      cd_date = Factory(:custom_definition,module_type:'Shipment',data_type:'date')
      cd_user_id = Factory(:custom_definition,module_type:'Shipment',data_type:'integer')
      btn = Factory(:state_toggle_button,module_type:'Shipment',
        date_custom_definition_id:cd_date.id,
        user_custom_definition_id:cd_user_id.id
      )
      u = Factory(:user)
      s = Factory(:shipment)


      s.should_receive(:create_snapshot_with_async_option).with(false,u)
      btn.toggle! s, u

      s.reload
      expect(s.get_custom_value(cd_date).value).to_not be_nil
      expect(s.get_custom_value(cd_user_id).value).to eq u.id
    end
    it "should clear custom value fields" do
      cd_date = Factory(:custom_definition,module_type:'Shipment',data_type:'date')
      cd_user_id = Factory(:custom_definition,module_type:'Shipment',data_type:'integer')
      btn = Factory(:state_toggle_button,module_type:'Shipment',
        date_custom_definition_id:cd_date.id,
        user_custom_definition_id:cd_user_id.id
      )
      u = Factory(:user)
      s = Factory(:shipment)
      s.get_custom_value(cd_date).value = Time.now
      s.get_custom_value(cd_user_id).value = u.id
      s.save!


      s.should_receive(:create_snapshot_with_async_option).with(false,u)
      btn.toggle! s, u

      s.reload
      expect(s.get_custom_value(cd_date).value).to be_nil
      expect(s.get_custom_value(cd_user_id).value).to be_nil
    end
    it "should respsect async snapshot" do
      btn = Factory(:state_toggle_button,module_type:'Shipment',date_attribute:'canceled_date',user_attribute:'canceled_by')
      s = Factory(:shipment)
      u = Factory(:user)

      s.should_receive(:create_snapshot_with_async_option).with(true,u)
      btn.toggle! s, u, true
    end
  end

  describe :to_be_activated? do
    it "should show activate if date_attribute and date_attribute value returns blank" do
      s = Shipment.new
      btn = StateToggleButton.new(date_attribute:'canceled_date')
      expect(btn.to_be_activated?(s)).to be_true
    end
    it "should not show activate if date_attribute and date_attribute value returns !blank" do
      s = Shipment.new(canceled_date:Time.now)
      btn = StateToggleButton.new(date_attribute:'canceled_date')
      expect(btn.to_be_activated?(s)).to be_false
    end
    it "should show activate if date_custom_definition and custom value returns blank" do
      cd_date = Factory(:custom_definition,module_type:'Shipment',data_type:'date')
      btn = Factory(:state_toggle_button,module_type:'Shipment',
        date_custom_definition_id:cd_date.id
      )
      s = Factory(:shipment)
      expect(btn.to_be_activated?(s)).to be_true
    end
    it "should not show activate if date_custom_definition and custom value returns !blank" do
      cd_date = Factory(:custom_definition,module_type:'Shipment',data_type:'date')
      btn = Factory(:state_toggle_button,module_type:'Shipment',
        date_custom_definition_id:cd_date.id
      )
      s = Factory(:shipment)
      s.get_custom_value(cd_date).value = Time.now
      s.save!
      expect(btn.to_be_activated?(s)).to be_false
    end
  end

  context :validations do
    it "should not allow with both date and custom date attributes" do
      cd_date = Factory(:custom_definition,module_type:'Shipment',data_type:'date')
      btn = StateToggleButton.new(module_type:'Shipment',date_attribute:'canceled_date',date_custom_definition:cd_date)
      expect{btn.save!}.to raise_error(/both date and custom date/)
    end
    it "should not allow with both user and custom user attributes" do
      cd_user = Factory(:custom_definition,module_type:'Shipment',data_type:'integer')
      btn = StateToggleButton.new(module_type:'Shipment',user_attribute:'canceled_by',user_custom_definition:cd_user)
      expect{btn.save!}.to raise_error(/both user and custom user/)
    end
  end
end
