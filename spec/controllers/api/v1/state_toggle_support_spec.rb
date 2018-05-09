describe Api::V1::ShipmentsController do

  let! (:user) { 
    u = Factory(:admin_user) 
    allow_api_access u
    u
  }

  let! (:shipment) { Factory(:shipment) }
  let! (:state_toggle_button) { StateToggleButton.create! date_attribute: "shp_isf_sent_at", user_attribute: "shp_isf_sent_by", identifier: "shp_isf_sent", disabled: false, module_type: "Shipment"}

  describe "toggle_state_button" do
    
    it "should toggle state" do
      btn = instance_double(StateToggleButton)
      expect(btn).to receive(:async_toggle!).with(shipment, user)
      allow(btn).to receive(:id).and_return 10
      expect(StateToggleButton).to receive(:for_core_object_user).with(shipment, user).and_return([btn])
      post :toggle_state_button, id: shipment.id.to_s, button_id: '10'
      expect(response).to be_success
    end
    
    it "should not toggle state if user cannot access button" do
      btn = instance_double(StateToggleButton)
      expect(btn).not_to receive(:async_toggle!).with(shipment, user)
      allow(btn).to receive(:id).and_return 10
      expect(StateToggleButton).to receive(:for_core_object_user).with(shipment, user).and_return([])
      post :toggle_state_button, id: shipment.id.to_s, button_id: '10'
      expect(response.status).to eq 403
    end

    it "allows access to the state toggle button via the button's identifier" do
      btn = instance_double(StateToggleButton)
      expect(btn).to receive(:async_toggle!).with(shipment, user)
      allow(btn).to receive(:id).and_return 10
      allow(btn).to receive(:identifier).and_return "identifier"
      expect(StateToggleButton).to receive(:for_core_object_user).with(shipment, user).and_return([btn])
      post :toggle_state_button, id: shipment.id.to_s, identifier: 'identifier'
      expect(response).to be_success
    end
  end

  describe "state_toggle_buttons" do

    it "should render result of render_state_toggle_buttons" do
      get :state_toggle_buttons, id: shipment.id

      expect(response).to be_success
      # I don't really care what the contents of the actual rendered buttons look like, just that there are some contents
      # there...the contents are tested elsewhere
      expect(JSON.parse(response.body)["state_toggle_buttons"].length).to eq 1
    end
  end
end
