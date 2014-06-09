require 'spec_helper'

describe ProjectSetsController do
  before :each do
    @u = Factory(:master_user, project_view: true)
    @p1 = Factory(:project)
    @p2 = Factory(:project)

    @ps = Factory(:project_set, projects: [@p1, @p2])
    sign_in_as @u
  end

  describe :show do
    it "should redirect for users who cannot view projects" do
      User.any_instance.stub(:view_projects?).and_return false
      get :show, id: @ps.id
      expect(response).to be_redirect
    end

    it "should render for users who can view projects" do
      get :show, id: @ps.id
      expect(response).to be_success
    end

    it "should correctly assign the project set" do
      get :show, id: @ps.id
      controller.instance_variable_get(:@project_set).should == @ps
    end

    it "should correctly assign the projects" do
      get :show, id: @ps.id
      controller.instance_variable_get(:@projects).should == [@p1, @p2]
    end
  end
end