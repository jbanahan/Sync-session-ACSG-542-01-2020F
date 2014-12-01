require 'spec_helper'

describe Api::V1::Admin::UsersController do
  describe :add_templates do
    it "should create new search setups based on the template" do
      allow_api_access Factory(:admin_user)
      u = Factory(:user)
      st = SearchTemplate.create!(name:'x',search_json:"{'a':'b'}")
      SearchTemplate.any_instance.should_receive(:add_to_user!).with(u)
      post :add_templates, id: u.id, template_ids: [st.id.to_s]
      expect(response).to be_success
    end
  end
end