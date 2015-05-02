require 'spec_helper'

describe Api::V1::CommentsController do
  before :each do
    @s = Factory(:shipment)
    @u = Factory(:user,first_name:'Joe',last_name:'Coward')
    Shipment.any_instance.stub(:can_view?).and_return true
    allow_api_access @u
  end
  describe :destroy do
    before :each do
      OpenChain::WorkflowProcessor.stub(:async_process)
    end
    it "should destroy if user is current_user" do
      OpenChain::WorkflowProcessor.should_receive(:async_process).with(instance_of(Shipment))
      c = @s.comments.create!(user_id:@u.id,subject:'s1',body:'b1')
      expect{delete :destroy, id: c.id.to_s}.to change(Comment,:count).from(1).to(0)
      expect(response).to be_success
    end
    it "should destroy if user is sys_admin" do
      @u.sys_admin = true
      @u.save!
      c = @s.comments.create!(user_id:Factory(:user).id,subject:'s1',body:'b1')
      expect{delete :destroy, id: c.id.to_s}.to change(Comment,:count).from(1).to(0)
      expect(response).to be_success
    end
    it "should not destroy if user is not current_user" do
      c = @s.comments.create!(user_id:Factory(:user).id,subject:'s1',body:'b1')
      expect{delete :destroy, id: c.id.to_s}.to_not change(Comment,:count)
      expect(response.status).to eq 401
    end
  end
  describe :create do
    before :each do
      Shipment.any_instance.stub(:can_comment?).and_return true
      @comment_hash = {comment:{commentable_id:@s.id.to_s,
        commentable_type:Shipment,
        subject:'sub',
        body:'bod'
      }}
    end
    it "should create comment" do
      OpenChain::WorkflowProcessor.stub(:async_process)
      OpenChain::WorkflowProcessor.should_receive(:async_process).with(instance_of(Shipment))
      expect{post :create, @comment_hash}.to change(Comment,:count).from(0).to(1)
      expect(response).to be_success
      expect(@s.comments.first.subject).to eq 'sub'
    end
    it "should 404 for bad commentable_type" do
      @comment_hash[:comment][:commentable_type] = 'OTHER'
      expect{post :create, @comment_hash}.to_not change(Comment,:count)
      expect(response.status).to eq 404
    end
    it "should 404 for bad commentable_id" do
      @comment_hash[:comment][:commentable_id] = -1
      expect{post :create, @comment_hash}.to_not change(Comment,:count)
      expect(response.status).to eq 404
    end
    it "should 401 if user cannot comment" do
      Shipment.any_instance.stub(:can_comment?).and_return false
      expect{post :create, @comment_hash}.to_not change(Comment,:count)
      expect(response.status).to eq 401
    end
  end
  describe :for_module do
    it "should return comments" do
      c1 = @s.comments.create!(user_id:@u.id,subject:'s1',body:'b1')
      c2 = @s.comments.create!(user_id:@u.id,subject:'s2',body:'b2')
      get :for_module, module_type:'Shipment', id: @s.id.to_s
      expect(response).to be_success
      j = JSON.parse response.body
      jc = j['comments']
      expect(jc.size).to eq 2
      expected_h = {'id'=>c1.id,'commentable_id'=>@s.id,'commentable_type'=>'Shipment',
        'subject'=>'s1','body'=>'b1'
      }
      expect(jc[0]['id']).to eq c1.id
      expect(jc[0]['commentable_id']).to eq @s.id
      expect(jc[0]['commentable_type']).to eq 'Shipment'
      expect(jc[0]['subject']).to eq 's1'
      expect(jc[0]['body']).to eq 'b1'
      expect(jc[0]['created_at']).to_not be_nil
      expect(jc[0]['user']['full_name']).to eq @u.full_name
      expected_permissions = {'can_view'=>true,'can_edit'=>true,'can_delete'=>true}
      expect(jc[0]['permissions']).to eq expected_permissions
    end
    it "should return empty array for no comments" do
      get :for_module, module_type:'Shipment', id: @s.id.to_s
      expect(response).to be_success
      j = JSON.parse response.body
      jc = j['comments']
      expect(jc).to eq []
    end
    it "should 400 if module type is bad" do
      get :for_module, module_type:'BAD', id: @s.id.to_s
      expect(response.status).to eq 404
    end
    it "should 400 if module object doesn't exist" do
      get :for_module, module_type:'Shipment', id: (@s.id + 1).to_s
      expect(response.status).to eq 404
    end
    it "should 401 if user cannot view" do
      Shipment.any_instance.stub(:can_view?).and_return false
      get :for_module, module_type:'Shipment', id: @s.id.to_s
      expect(response.status).to eq 401
    end
  end
end