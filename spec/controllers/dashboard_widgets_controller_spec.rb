require 'spec_helper'

describe DashboardWidgetsController do

  before :each do
    @user = Factory(:master_user,:email=>'a@example.com')
    sign_in_as @user

    @search_setup = Factory(:search_setup, user: @user)
    @dashboard_widget = DashboardWidget.new
    @dashboard_widget.user = @user
    @dashboard_widget.search_setup = @search_setup
    @user.dashboard_widgets << @dashboard_widget
    @user.search_setups << @search_setup
    @user.save!
  end

  describe "index" do
    it "sets the widgets" do
      get :index
      expect(assigns(:widgets)).to eq [@dashboard_widget]
    end
  end

  describe "edit" do
    it "sets widgets and searches" do 
      ss2 = Factory(:search_setup, module_type: "Entry", user: @user)
      @user.search_setups << ss2
      @user.save!

      get :edit
      expect(assigns(:widgets)).to eq [@dashboard_widget]
      expect(assigns(:searches)).to eq [ss2, @search_setup]
    end
  end

  describe "save" do
    it "saves a dashboard layout" do
      ss2 = Factory(:search_setup, module_type: "Entry", user: @user)
      p = {:dashboard_widget => {'0' => {search_setup_id: ss2.id, rank: 0}}}

      post :save, p

      expect(response).to redirect_to dashboard_widgets_path
      @user.reload

      expect(@user.dashboard_widgets).to have(1).item
      expect(@user.dashboard_widgets.first.search_setup).to eq ss2
    end

    it "clears search setup ids" do
      p = {:dashboard_widget => {'0' => {search_setup_id: "none", rank: 0}}}

      post :save, p

      expect(response).to redirect_to dashboard_widgets_path
      @user.reload

      expect(@user.dashboard_widgets).to have(0).items
    end
  end

end
