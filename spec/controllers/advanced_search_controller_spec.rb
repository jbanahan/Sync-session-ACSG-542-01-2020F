require 'spec_helper'

describe AdvancedSearchController do
  before :each do
    @user = Factory(:user)
    activate_authlogic
    UserSession.create! @user
  end

  describe :result do
    render_views

    before :each do
      @ss = Factory(:search_setup,:module_type=>"Product")
      @ss.search_columns.create!(:model_field_uid=>:prod_uid,:rank=>0)
    end

    it "should get result" do
      get 'result', :id=>@ss.id
      response.should render_template(:partial => '_rows')
    end
  end
  describe :row_count do
    SearchQuery.any_instance.stub(:count).and_return 55
    get 'count', :id=>@ss.id
    response.body.should == "55"
  end
end
