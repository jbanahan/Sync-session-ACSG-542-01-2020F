describe StateToggleButton do

  let (:shipment) { FactoryBot(:shipment, importer_reference: "12345") }
  let! (:state_toggle_button) { FactoryBot(:state_toggle_button, module_type: 'Shipment', date_attribute: 'shp_canceled_date', user_attribute: 'shp_canceled_by') }
  let (:user) { FactoryBot(:user) }

  describe "for_core_object_user" do
    subject { described_class }

    it "finds from same core_module" do
      FactoryBot(:state_toggle_button, module_type: 'Order', date_attribute: 'ord_accepted_at', user_attribute: 'ord_accepted_by') # don't find
      expect(subject.for_core_object_user(shipment, user)).to eq [state_toggle_button]
    end

    it "filters by search_criterion" do
      state_toggle_button.search_criterions.create!(model_field_uid: 'shp_importer_reference', operator: 'eq', value: '12345')
      btn2 = FactoryBot(:state_toggle_button,  module_type: 'Shipment', date_attribute: 'shp_canceled_date', user_attribute: 'shp_canceled_by')
      btn2.search_criterions.create!(model_field_uid: 'shp_importer_reference', operator: 'eq', value: 'DEF')

      expect(subject.for_core_object_user(shipment, user)).to eq [state_toggle_button]
    end

    it "does not find if user not in any permission group" do
      state_toggle_button.update! permission_group_system_codes: "GRPA\nGRPB\nGRPC"

      expect(subject.for_core_object_user(shipment, user)).to eq []
    end

    it "finds if user in a permission group" do
      state_toggle_button.update! permission_group_system_codes: "GRPA\nGRPB\nGRPC"
      user.groups << Group.use_system_group('GRPB')
      expect(subject.for_core_object_user(shipment, user)).to eq [state_toggle_button]
    end

    it "skips disabled buttons" do
      state_toggle_button.update! disabled: true

      expect(subject.for_core_object_user(shipment, user)).to eq []
    end
  end

  describe "toggle!" do

    it "sets the date and user_id fields" do
      expect(shipment).to receive(:create_snapshot_with_async_option).with(false, user)

      now = Time.zone.parse("2018-01-01 12:00")
      Timecop.freeze(now) { state_toggle_button.toggle_state! shipment, user }

      shipment.reload
      expect(shipment.canceled_date).to eq now
      expect(shipment.canceled_by).to eq user
    end

    it "clears the date and user_id fields" do
      FactoryBot(:state_toggle_button, module_type: 'Shipment', date_attribute: 'shp_canceled_date', user_attribute: 'shp_canceled_by')

      shipment.update! canceled_date: 1.day.ago, canceled_by: user

      expect(shipment).to receive(:create_snapshot_with_async_option).with(false, user)
      state_toggle_button.toggle_state! shipment, user

      shipment.reload
      expect(shipment.canceled_date).to be_nil
      expect(shipment.canceled_by).to be_nil
    end

    it "prefers date when fields are in opposite state" do
      shipment.update! canceled_date: 1.day.ago, canceled_by: nil

      expect(shipment).to receive(:create_snapshot_with_async_option).with(false, user)
      state_toggle_button.toggle_state! shipment, user

      shipment.reload
      expect(shipment.canceled_date).to be_nil
      expect(shipment.canceled_by).to be_nil
    end

    it "sets custom value fields" do
      cd_date = FactoryBot(:custom_definition, module_type: 'Shipment', data_type: 'datetime')
      cd_user_id = FactoryBot(:custom_definition, module_type: 'Shipment', data_type: 'integer', is_user: true)
      state_toggle_button.update! date_custom_definition_id: cd_date.id, user_custom_definition_id: cd_user_id.id, date_attribute: nil, user_attribute: nil

      expect(shipment).to receive(:create_snapshot_with_async_option).with(false, user)
      now = Time.zone.parse("2018-01-01 12:00")
      Timecop.freeze(now) { state_toggle_button.toggle_state! shipment, user }

      shipment.reload
      expect(shipment.custom_value(cd_date)).to eq now
      expect(shipment.custom_value(cd_user_id)).to eq user.id
    end

    it "clears custom value fields" do
      cd_date = FactoryBot(:custom_definition, module_type: 'Shipment', data_type: 'date')
      cd_user_id = FactoryBot(:custom_definition, module_type: 'Shipment', data_type: 'integer')
      state_toggle_button.update! date_custom_definition_id: cd_date.id, user_custom_definition_id: cd_user_id.id, date_attribute: nil, user_attribute: nil

      shipment.get_custom_value(cd_date).value = Time.zone.now
      shipment.get_custom_value(cd_user_id).value = user.id
      shipment.save!

      expect(shipment).to receive(:create_snapshot_with_async_option).with(false, user)
      state_toggle_button.toggle_state! shipment, user

      shipment.reload
      expect(shipment.get_custom_value(cd_date).value).to be_nil
      expect(shipment.get_custom_value(cd_user_id).value).to be_nil
    end

    it "respects async snapshot parameter" do
      expect(shipment).to receive(:create_snapshot_with_async_option).with(true, user)
      state_toggle_button.toggle_state! shipment, user, true
    end

    it "updates last_updated_by if present" do
      # Product has a last updated by field.
      prod = FactoryBot(:product, unique_identifier: "12345")
      cd_date = FactoryBot(:custom_definition, module_type: 'Product', data_type: 'datetime')
      cd_user_id = FactoryBot(:custom_definition, module_type: 'Product', data_type: 'integer', is_user: true)

      state_toggle_button_prod = FactoryBot(:state_toggle_button, module_type: 'Product',
                                                               date_custom_definition_id: cd_date.id,
                                                               user_custom_definition_id: cd_user_id.id,
                                                               date_attribute: nil,
                                                               user_attribute: nil)

      expect(prod).to receive(:create_snapshot_with_async_option).with(false, user)
      now = Time.zone.parse("2018-01-01 12:00")
      Timecop.freeze(now) { state_toggle_button_prod.toggle_state! prod, user }

      prod.reload
      expect(prod.custom_value(cd_date)).to eq now
      expect(prod.custom_value(cd_user_id)).to eq user.id
      expect(prod.updated_at).to eq now
      expect(prod.last_updated_by).to eq user
    end
  end

  describe "to_be_activated?" do
    it "shows activate if date_attribute and date_attribute value returns blank" do
      s = Shipment.new
      expect(state_toggle_button.to_be_activated?(s)).to eq true
    end

    it "does not show activate if date_attribute and date_attribute value returns !blank" do
      s = Shipment.new(canceled_date: Time.zone.now)
      expect(state_toggle_button.to_be_activated?(s)).to eq false
    end

    it "shows activate if date_custom_definition and custom value returns blank" do
      cd_date = FactoryBot(:custom_definition, module_type: 'Shipment', data_type: 'date')
      cd_user_id = FactoryBot(:custom_definition, module_type: 'Shipment', data_type: 'integer')
      state_toggle_button.update! date_custom_definition_id: cd_date.id, user_custom_definition_id: cd_user_id.id, date_attribute: nil, user_attribute: nil

      s = FactoryBot(:shipment)
      expect(state_toggle_button.to_be_activated?(s)).to eq true
    end

    it "does not show activate if date_custom_definition and custom value returns !blank" do
      cd_date = FactoryBot(:custom_definition, module_type: 'Shipment', data_type: 'date')
      cd_user_id = FactoryBot(:custom_definition, module_type: 'Shipment', data_type: 'integer')
      state_toggle_button.update! date_custom_definition_id: cd_date.id, user_custom_definition_id: cd_user_id.id, date_attribute: nil, user_attribute: nil

      shipment.get_custom_value(cd_date).value = Time.zone.now
      shipment.save!
      expect(state_toggle_button.to_be_activated?(shipment)).to eq false
    end
  end

  context "validations" do
    it "does not allow with both date and custom date attributes" do
      cd_date = FactoryBot(:custom_definition, module_type: 'Shipment', data_type: 'date')
      btn = described_class.new(module_type: 'Shipment', date_attribute: 'canceled_date', date_custom_definition_id: cd_date.id)
      expect {btn.save!}.to raise_error(/both date and custom date/)
    end

    it "does not allow with both user and custom user attributes" do
      cd_user = FactoryBot(:custom_definition, module_type: 'Shipment', data_type: 'integer')
      btn = described_class.new(module_type: 'Shipment', user_attribute: 'canceled_by', user_custom_definition_id: cd_user.id)
      expect {btn.save!}.to raise_error(/both user and custom user/)
    end
  end

  context "field getters" do
    let!(:user_cdef) { FactoryBot(:custom_definition, module_type: "Order", data_type: "integer", label: "Custom User", is_user: true)}
    let!(:date_cdef) { FactoryBot(:custom_definition, module_type: "Order", data_type: "datetime", label: "Custom Date")}
    let(:stb) { FactoryBot(:state_toggle_button, module_type: "Order", user_custom_definition_id: user_cdef.id, date_custom_definition_id: date_cdef.id) }

    describe "user_field" do

      it "retrieves model field if the button has a user_attribute" do
        stb.update!(user_custom_definition_id: nil, user_attribute: "ord_closed_by")
        expect(stb.user_field.label).to eq "Closed By"
      end

      it "retrieves custom definition if the button has a user_custom_definition_id" do
        stb.update!(user_custom_definition_id: user_cdef.id, user_attribute: nil)
        expect(stb.user_field.label).to eq "Custom User"
      end
    end

    describe "date_field" do
      it "retrieves model field if the button has a date_attribute" do
        stb.update!(date_custom_definition_id: nil, date_attribute: "ord_closed_at")
        expect(stb.date_field.label).to eq "Closed At"
      end

      it "retrieves custom definition if the button has a date_custom_definition_id" do
        stb.update!(date_custom_definition_id: date_cdef.id, date_attribute: nil)
        expect(stb.date_field.label).to eq "Custom Date"
      end
    end
  end
end
