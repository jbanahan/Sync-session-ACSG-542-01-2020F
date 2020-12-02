describe SearchTemplatesController do
  describe "destroy" do
    it "should delete search template" do
      u = create(:admin_user)
      sign_in_as u
      st = create(:search_template)
      expect {delete :destroy, :id=>st.id}.to change(SearchTemplate, :count).from(1).to(0)
    end
  end
end
