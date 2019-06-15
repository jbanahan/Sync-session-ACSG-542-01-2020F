describe ProjectSetsController do
  before :each do
    @u = Factory(:master_user, project_view: true)
    @p1 = Factory(:project)
    @p2 = Factory(:project)

    @ps = Factory(:project_set, projects: [@p1, @p2])
    sign_in_as @u
  end

  describe "show" do
    it "should redirect for users who cannot view projects" do
      allow_any_instance_of(User).to receive(:view_projects?).and_return false
      get :show, id: @ps.id
      expect(response).to be_redirect
    end

    it "should render for users who can view projects" do
      get :show, id: @ps.id
      expect(response).to be_success
    end

    it "should correctly assign the project set" do
      get :show, id: @ps.id
      expect(controller.instance_variable_get(:@project_set)).to eq(@ps)
    end

    it "should correctly assign the projects" do
      get :show, id: @ps.id
      expect(controller.instance_variable_get(:@projects)).to eq([@p1, @p2])
    end
  end
end
