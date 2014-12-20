require 'spec_helper' 

describe WorkflowController do
  before :each do
    @u = Factory(:user)
    sign_in_as @u
  end
  describe "show" do
    it "should get all workflow instances for core_object" do
      Order.any_instance.stub(:can_view?).and_return(true)
      o = Factory(:order)
      w1 = Factory(:workflow_instance,base_object:o)
      w2 = Factory(:workflow_instance,base_object:o)
      ignore_me = Factory(:workflow_instance)

      get :show, core_module:'Order', id:o.id.to_s
      expect(response).to be_success
      expect(assigns(:workflow_instances).to_a).to eq [w1,w2]
    end
    it "should fail if user cannot view core_object" do
      Order.any_instance.stub(:can_view?).and_return(false)
      o = Factory(:order)
      
      expect{get :show, core_module:'Order', id:o.id.to_s}.to raise_error ActionController::RoutingError
    end
    it "should 404 if :core_module doesn't exist" do
      expect{get :show, core_module:'BadObj', id:1.to_s}.to raise_error ActionController::RoutingError
    end
  end
end