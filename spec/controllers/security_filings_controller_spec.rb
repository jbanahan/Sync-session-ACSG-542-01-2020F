require 'spec_helper'

describe SecurityFilingsController do
  before :each do

    @u = Factory(:user)
    sign_in_as @u
  end
  describe "show" do
    before :each do
      @sf = Factory(:security_filing)
    end
    it "should allow user who can view the given filing" do
      allow_any_instance_of(SecurityFiling).to receive(:can_view?).and_return(true)
      get :show, :id=>@sf.id
      expect(response).to be_success
      expect(assigns(:security_filing)).to eq(@sf)
    end
    it "should not allow user who cannot view the given security filing" do
      allow_any_instance_of(SecurityFiling).to receive(:can_view?).and_return(false)
      get :show, :id=>@sf.id
      expect(response).to redirect_to request.referrer
      expect(assigns(:security_filing)).to be_nil
      expect(flash[:errors].size).to eq(1)
    end
  end
end
