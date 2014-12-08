require 'spec_helper'

describe SearchTemplatesController do
  describe :destroy do
    it "should delete search template" do
      u = Factory(:admin_user)
      sign_in_as u
      st = Factory(:search_template)
      expect{delete :destroy, :id=>st.id}.to change(SearchTemplate,:count).from(1).to(0)
    end
  end
end