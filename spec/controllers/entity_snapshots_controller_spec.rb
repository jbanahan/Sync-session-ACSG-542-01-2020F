require 'spec_helper'

describe EntitySnapshotsController do
  describe :restore do
    before :each do
      @u = Factory(:user)
      @p = Factory(:product,:name=>'nm')
      @es = @p.create_snapshot @u
      @p.update_attributes(:name=>'new name')
      allow_any_instance_of(Product).to receive(:can_edit?).and_return(true)

      sign_in_as @u
    end
    it "should restore object" do
      post :restore, :id=>@es.id.to_s
      expect(response).to redirect_to @p
      expect(flash[:notices].first).to eq("Object restored successfully.")
      @p.reload
      expect(@p.name).to eq('nm')
    end
    it "should not restore if user cannot edit parent object" do
      allow_any_instance_of(Product).to receive(:can_edit?).and_return(false)
      post :restore, :id=>@es.id.to_s
      expect(response).to redirect_to request.referrer
      expect(flash[:errors].first).to eq("You cannot restore this object because you do not have permission to edit it.")
      @p.reload
      expect(@p.name).to eq('new name')
    end
  end
end
