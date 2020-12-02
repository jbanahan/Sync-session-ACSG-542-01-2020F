describe OpenChain::Api::V1::CoreModuleApiJsonSupport do

  subject {
    Class.new {
      include OpenChain::Api::V1::CoreModuleApiJsonSupport
    }.new
  }

  describe "render_state_toggle_buttons?" do
    it "returns false if params 'include' value doesn't not have the text 'state_toggle_buttons'" do
      expect(subject.render_state_toggle_buttons?({include: "blah"})).to eq false
    end

    it "returns true if params 'include' value has the text 'state_toggle_buttons'" do
      expect(subject.render_state_toggle_buttons?({include: "field,state_toggle_buttons,another_field"})).to eq true
    end
  end

  describe "render_state_toggle_buttons" do
    let! (:button) { create(:state_toggle_button,
        activate_text:'A', activate_confirmation_text:'B', module_type: "Shipment", user_attribute: "shp_canceled_by", date_attribute: "shp_canceled_date",
        deactivate_text:'C', deactivate_confirmation_text:'D', simple_button: false, identifier: "identifier", display_index: 1)
    }
    let (:user) { create(:user) }
    let (:object) { create(:shipment) }

    it "return array of buttons hash data" do
      expect(StateToggleButton).to receive(:for_core_object_user).with(object, user).and_return([button])
      allow(button).to receive(:to_be_activated?).and_return(true)

      expect(subject.render_state_toggle_buttons(object, user)).to eq [
        {id:button.id, button_text:'A', button_confirmation:'B', core_module_path:'shipments', base_object_id:object.id,
          simple_button: false, identifier: "identifier", display_index: 1}
      ]
    end

    it "should return activation based on to_be_activated? state" do
      expect(StateToggleButton).to receive(:for_core_object_user).with(object, user).and_return([button])
      allow(button).to receive(:to_be_activated?).and_return(false)

      expect(subject.render_state_toggle_buttons(object, user)).to eq [
        {id:button.id, button_text:'C', button_confirmation:'D', core_module_path:'shipments', base_object_id:object.id,
          simple_button: false, identifier: "identifier", display_index: 1}
      ]
    end

    context "with state toggle buttons" do
      before :each do
        allow(StateToggleButton).to receive(:for_core_object_user).and_return([button])
      end

      it "does not render buttons if params are passed without a 'state_toggle_button' include" do
        expect(subject.render_state_toggle_buttons(object, user, params: {})).to eq []
      end

      it "renders buttons if params are passed without a 'state_toggle_button' include" do
        expect(subject.render_state_toggle_buttons(object, user, params: {include: "state_toggle_buttons"}).size).to eq 1
      end

      it "renders buttons to a hash object if provided" do
        hash = {}
        buttons = subject.render_state_toggle_buttons(object, user, api_hash: hash)
        expect(hash[:state_toggle_buttons]).to eq buttons
      end
    end
  end
end