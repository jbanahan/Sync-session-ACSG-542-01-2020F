require 'spec_helper'

describe Api::V1::CompaniesController do #because we have to test on some concrete controller
  before :each do
    @c = Factory(:company)
    @u = Factory(:admin_user)
    allow_api_access @u
  end
  describe :toggle_state_button do
    it "should toggle state" do
      btn = double('state toggle button')
      btn.should_receive(:async_toggle!).with(@c,@u)
      btn.stub(:id).and_return 10
      StateToggleButton.should_receive(:for_core_object_user).with(@c,@u).and_return([btn])
      post :toggle_state_button, id: @c.id.to_s, button_id: '10'
      expect(response).to be_success
    end
    it "should not toggle state if user cannot access button" do
      btn = double('state toggle button')
      btn.should_not_receive(:async_toggle!).with(@c,@u)
      btn.stub(:id).and_return 10
      StateToggleButton.should_receive(:for_core_object_user).with(@c,@u).and_return([])
      post :toggle_state_button, id: @c.id.to_s, button_id: '10'
      expect(response.status).to eq 403
    end
  end

  describe :state_toggle_buttons do
    it "should render result of render_state_toggle_buttons" do
      described_class.any_instance.should_receive(:render_state_toggle_buttons).with(@c,@u).and_return([{a:'b'}])

      get :state_toggle_buttons, id: @c.id.to_s

      expect(response).to be_success
      expected = {'state_toggle_buttons'=>[{'a'=>'b'}]}
      expect(response.body).to eq expected.to_json
    end
  end

  #this is separate from the API method so they can be injected in other calls
  describe :render_state_toggle_buttons do
    before :each do
      @btn = Factory(:state_toggle_button,
        activate_text:'A',activate_confirmation_text:'B',
        deactivate_text:'C',deactivate_confirmation_text:'D'
      )
    end
    it "should return array of buttons hash data" do
      StateToggleButton.should_receive(:for_core_object_user).with(@c,@u).and_return([@btn])
      @btn.stub(:to_be_activated?).and_return(true)

      expect(described_class.new.render_state_toggle_buttons(@c,@u)).to eq [
        {id:@btn.id,button_text:'A',button_confirmation:'B',
          core_module_path:'companies',base_object_id:@c.id}
      ]
    end
    it "should return activation based on to_be_activated? state" do
      StateToggleButton.should_receive(:for_core_object_user).with(@c,@u).and_return([@btn])
      @btn.stub(:to_be_activated?).and_return(false)

      expect(described_class.new.render_state_toggle_buttons(@c,@u)).to eq [
        {id:@btn.id,button_text:'C',button_confirmation:'D',
          core_module_path:'companies',base_object_id:@c.id}
      ]
    end
  end
end
