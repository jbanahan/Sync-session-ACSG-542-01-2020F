require 'spec_helper'

describe Api::V1::CompaniesController do #because we have to test on some concrete controller
  before :each do
    @c = Factory(:company)
    @u = Factory(:admin_user)
    allow_api_access @u
  end
  describe "toggle_state_button" do
    it "should toggle state" do
      btn = instance_double(StateToggleButton)
      expect(btn).to receive(:async_toggle!).with(@c,@u)
      allow(btn).to receive(:id).and_return 10
      expect(StateToggleButton).to receive(:for_core_object_user).with(@c,@u).and_return([btn])
      post :toggle_state_button, id: @c.id.to_s, button_id: '10'
      expect(response).to be_success
    end
    it "should not toggle state if user cannot access button" do
      btn = instance_double(StateToggleButton)
      expect(btn).not_to receive(:async_toggle!).with(@c,@u)
      allow(btn).to receive(:id).and_return 10
      expect(StateToggleButton).to receive(:for_core_object_user).with(@c,@u).and_return([])
      post :toggle_state_button, id: @c.id.to_s, button_id: '10'
      expect(response.status).to eq 403
    end
    it "allows access to the state toggle button via the button's identifier" do
      btn = instance_double(StateToggleButton)
      expect(btn).to receive(:async_toggle!).with(@c,@u)
      allow(btn).to receive(:id).and_return 10
      allow(btn).to receive(:identifier).and_return "identifier"
      expect(StateToggleButton).to receive(:for_core_object_user).with(@c,@u).and_return([btn])
      post :toggle_state_button, id: @c.id.to_s, identifier: 'identifier'
      expect(response).to be_success
    end
  end

  describe "state_toggle_buttons" do
    it "should render result of render_state_toggle_buttons" do
      expect_any_instance_of(described_class).to receive(:render_state_toggle_buttons).with(@c,@u, api_hash: {}).and_return({"state_toggle_buttons" => [{a:'b'}]})

      get :state_toggle_buttons, id: @c.id.to_s

      expect(response).to be_success
      expected = {'state_toggle_buttons'=>[{'a'=>'b'}]}
      expect(response.body).to eq expected.to_json
    end
  end
end
