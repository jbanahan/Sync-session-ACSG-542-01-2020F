describe Api::V1::CommentsController do
  let!(:user) { Factory(:user, first_name: 'Joe', last_name: 'Coward', time_zone: "America/New_York") }
  let(:shipment) { Factory(:shipment) }

  before do
    allow_any_instance_of(Shipment).to receive(:can_view?).and_return true
    allow_api_access user
  end

  describe "destroy" do
    it "destroys if user is current_user" do
      c = shipment.comments.create!(user_id: user.id, subject: 's1', body: 'b1')
      expect {delete :destroy, id: c.id.to_s}.to change(Comment, :count).from(1).to(0)
      expect(response).to be_success
    end

    it "destroys if user is sys_admin" do
      user.sys_admin = true
      user.save!
      c = shipment.comments.create!(user_id: Factory(:user).id, subject: 's1', body: 'b1')
      expect {delete :destroy, id: c.id.to_s}.to change(Comment, :count).from(1).to(0)
      expect(response).to be_success
    end

    it "does not destroy if user is not current_user" do
      c = shipment.comments.create!(user_id: Factory(:user).id, subject: 's1', body: 'b1')
      expect {delete :destroy, id: c.id.to_s}.not_to change(Comment, :count)
      expect(response.status).to eq 401
    end
  end

  describe "create" do
    let(:comment_hash) do
      {comment: {commentable_id: shipment.id.to_s,
                 commentable_type: Shipment,
                 subject: 'sub',
                 body: 'bod'}}
    end

    before do
      allow_any_instance_of(Shipment).to receive(:can_comment?).and_return true
    end

    it "creates comment" do
      expect {post :create, comment_hash}.to change(Comment, :count).from(0).to(1)
      expect(response).to be_success
      expect(shipment.comments.first.subject).to eq 'sub'
    end

    it "404S for bad commentable_type" do
      comment_hash[:comment][:commentable_type] = 'OTHER'
      expect {post :create, comment_hash}.not_to change(Comment, :count)
      expect(response.status).to eq 404
    end

    it "404S for bad commentable_id" do
      comment_hash[:comment][:commentable_id] = -1
      expect {post :create, comment_hash}.not_to change(Comment, :count)
      expect(response.status).to eq 404
    end

    it "401S if user cannot comment" do
      allow_any_instance_of(Shipment).to receive(:can_comment?).and_return false
      expect {post :create, comment_hash}.not_to change(Comment, :count)
      expect(response.status).to eq 401
    end
  end

  describe "for_module" do
    it "returns comments" do
      c1 = shipment.comments.create!(user_id: user.id, subject: 's1', body: 'b1')
      shipment.comments.create!(user_id: user.id, subject: 's2', body: 'b2')
      get :for_module, module_type: 'Shipment', id: shipment.id.to_s
      expect(response).to be_success
      j = JSON.parse response.body
      jc = j['comments']
      expect(jc.size).to eq 2

      comment = jc.find {|c| c["id"].to_i == c1.id}

      expect(comment).not_to be_nil
      expect(comment['commentable_id']).to eq shipment.id
      expect(comment['commentable_type']).to eq 'Shipment'
      expect(comment['subject']).to eq 's1'
      expect(comment['body']).to eq 'b1'
      expect(comment['created_at']).not_to be_nil
      expect(comment['user']['full_name']).to eq user.full_name
      expected_permissions = {'can_view' => true, 'can_edit' => true, 'can_delete' => true}
      expect(comment['permissions']).to eq expected_permissions
    end

    it "returns empty array for no comments" do
      get :for_module, module_type: 'Shipment', id: shipment.id.to_s
      expect(response).to be_success
      j = JSON.parse response.body
      jc = j['comments']
      expect(jc).to eq []
    end

    it "400S if module type is bad" do
      get :for_module, module_type: 'BAD', id: shipment.id.to_s
      expect(response.status).to eq 404
    end

    it "400S if module object doesn't exist" do
      get :for_module, module_type: 'Shipment', id: (shipment.id + 1).to_s
      expect(response.status).to eq 404
    end

    it "401S if user cannot view" do
      allow_any_instance_of(Shipment).to receive(:can_view?).and_return false
      get :for_module, module_type: 'Shipment', id: shipment.id.to_s
      expect(response.status).to eq 401
    end
  end

  context "polymorphic methods" do
    let! (:comment) { shipment.comments.create!(user_id: user.id, subject: 's1', body: 'b1') }

    describe "polymorphic_index" do
      it "returns all comments from an object" do
        get :polymorphic_index, base_object_type: "shipments", base_object_id: shipment.id
        expect(response).to be_success
        j = JSON.parse(response.body)
        expect(j).to eq({
                          "comments" => [{"id" => comment.id, "cmt_unique_identifier" => "#{comment.id}-s1",
                                          "cmt_subject" => "s1", "cmt_body" => "b1",
                                          "cmt_created_at" => comment.created_at.in_time_zone(user.time_zone).iso8601,
                                          "cmt_user_username" => user.username, "cmt_user_fullname" => user.full_name,
                                          "cmt_user" => user.id}]
                        })
      end

      it "includes permissions if requested" do
        get :polymorphic_index, base_object_type: "shipments", base_object_id: shipment.id, include: "permissions"
        expect(response).to be_success
        j = JSON.parse(response.body)
        expect(j).to eq({
                          "comments" => [
                            {"id" => comment.id, "cmt_unique_identifier" => "#{comment.id}-s1", "cmt_subject" => "s1",
                             "cmt_body" => "b1", "cmt_created_at" => comment.created_at.in_time_zone(user.time_zone).iso8601,
                             "cmt_user_username" => user.username, "cmt_user_fullname" => user.full_name,
                             "cmt_user" => user.id,
                             "permissions" => {
                               'can_view' => true, 'can_edit' => true, 'can_delete' => true
                             }}]
                        })
      end

      it "errors if user can't view base object" do
        allow_any_instance_of(Shipment).to receive(:can_view?).with(user).and_return false
        get :polymorphic_index, base_object_type: "shipments", base_object_id: shipment.id, include: "permissions"
        expect(response).not_to be_success
        expect(response.status).to eq 403
      end
    end

    describe "polymorphic_show" do

      it "shows comment" do
        get :polymorphic_show, base_object_type: "shipments", base_object_id: shipment.id, id: comment.id
        expect(response).to be_success
        j = JSON.parse(response.body)
        expect(j).to eq({
                          "comment" => {"id" => comment.id, "cmt_unique_identifier" => "#{comment.id}-s1",
                                        "cmt_subject" => "s1", "cmt_body" => "b1",
                                        "cmt_created_at" => comment.created_at.in_time_zone(user.time_zone).iso8601,
                                        "cmt_user_username" => user.username, "cmt_user_fullname" => user.full_name,
                                        "cmt_user" => user.id}
                        })
      end

      it "sends permissions if requested" do
        get :polymorphic_show, base_object_type: "shipments", base_object_id: shipment.id, id: comment.id, include: "permissions"
        expect(response).to be_success
        j = JSON.parse(response.body)
        expect(j).to eq({
                          "comment" => {"id" => comment.id, "cmt_unique_identifier" => "#{comment.id}-s1",
                                        "cmt_subject" => "s1", "cmt_body" => "b1",
                                        "cmt_created_at" => comment.created_at.in_time_zone(user.time_zone).iso8601,
                                        "cmt_user_username" => user.username, "cmt_user_fullname" => user.full_name,
                                        "cmt_user" => user.id,
                                        "permissions" => {
                                          'can_view' => true, 'can_edit' => true, 'can_delete' => true
                                        }}
                        })
      end

      it "errors if user can't view shipment" do
        allow_any_instance_of(Shipment).to receive(:can_view?).with(user).and_return false
        get :polymorphic_show, base_object_type: "shipments", base_object_id: shipment.id, id: comment.id
        expect(response).not_to be_success
        expect(response.status).to eq 403
      end
    end

    describe "polymorphic_destroy" do

      before do
        allow_any_instance_of(Shipment).to receive(:can_comment?).with(user).and_return true
      end

      it "destroys comment" do
        expect_any_instance_of(Shipment).to receive(:create_async_snapshot).with user
        delete :polymorphic_destroy, base_object_type: "shipments", base_object_id: shipment.id, id: comment.id
        expect(response).to be_success
        expect(JSON.parse(response.body)).to eq({"ok" => "ok"})

        shipment.reload
        expect(shipment.comments.length).to eq 0
      end

      it "does not destroy comments owned by another user" do
        u = Factory(:user)
        c = shipment.comments.create! user_id: u.id, subject: "Sub", body: "Bod"

        expect_any_instance_of(Shipment).not_to receive(:create_async_snapshot)
        delete :polymorphic_destroy, base_object_type: "shipments", base_object_id: shipment.id, id: c.id
        expect(response).not_to be_success
        expect(response.status).to eq 403

        shipment.reload
        expect(shipment.comments.length).to eq 2
      end

      it "does not destroy comments when user cannot comment on obj" do
        allow_any_instance_of(Shipment).to receive(:can_comment?).with(user).and_return false

        expect_any_instance_of(Shipment).not_to receive(:create_async_snapshot)
        delete :polymorphic_destroy, base_object_type: "shipments", base_object_id: shipment.id, id: comment.id
        expect(response).not_to be_success
        expect(response.status).to eq 403

        shipment.reload
        expect(shipment.comments.length).to eq 1
      end
    end

    describe "polymorphic_create" do
      before do
        allow_any_instance_of(Shipment).to receive(:can_comment?).with(user).and_return true
        shipment.comments.destroy_all
      end

      it "creates a comment" do
        expect_any_instance_of(Shipment).to receive(:create_async_snapshot).with user
        post :polymorphic_create, base_object_type: "shipments", base_object_id: shipment.id, comment: {cmt_subject: "Subject", cmt_body: "Body"}
        expect(response).to be_success

        j = JSON.parse(response.body)
        # Just make sure the body, subject given are used...since we won't know the id utilized
        # This uses the same view method as show and index, so the hash keys / vlaues are already well tested
        expect(j['comment']['cmt_subject']).to eq "Subject"
        expect(j['comment']['cmt_body']).to eq "Body"
        expect(j['comment']['cmt_user']).to eq user.id

        shipment.reload
        expect(shipment.comments.first.id).to eq j['comment']['id']
      end

      it "creates a comment, returning permissions" do
        expect_any_instance_of(Shipment).to receive(:create_async_snapshot).with user
        post :polymorphic_create, base_object_type: "shipments", base_object_id: shipment.id, comment: {cmt_subject: "Subject", cmt_body: "Body"}, include: "permissions"
        expect(response).to be_success

        j = JSON.parse(response.body)
        expect(j['comment']['permissions']).not_to be_nil
      end

      it "fails if user cannot comment on object" do
        allow_any_instance_of(Shipment).to receive(:can_comment?).with(user).and_return false

        expect_any_instance_of(Shipment).not_to receive(:create_async_snapshot)
        post :polymorphic_create, base_object_type: "shipments", base_object_id: shipment.id, cmt_subject: "Subject", cmt_body: "Body"
        expect(response).not_to be_success
        expect(response.status).to eq 403
      end
    end

  end

end
