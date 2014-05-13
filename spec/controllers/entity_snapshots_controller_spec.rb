require 'spec_helper'

describe EntitySnapshotsController do
  describe :restore do
    before :each do
      @u = Factory(:user)
      @p = Factory(:product,:name=>'nm')
      @es = @p.create_snapshot @u
      @p.update_attributes(:name=>'new name')
      Product.any_instance.stub(:can_edit?).and_return(true)

      sign_in_as @u
    end
    it "should restore object" do
      post :restore, :id=>@es.id.to_s
      response.should redirect_to @p
      flash[:notices].first.should == "Object restored successfully."
      @p.reload
      @p.name.should == 'nm'
    end
    it "should not restore if user cannot edit parent object" do
      Product.any_instance.stub(:can_edit?).and_return(false)
      post :restore, :id=>@es.id.to_s
      response.should redirect_to request.referrer
      flash[:errors].first.should == "You cannot restore this object because you do not have permission to edit it."
      @p.reload
      @p.name.should == 'new name'
    end
  end
end
