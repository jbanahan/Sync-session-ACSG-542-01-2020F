describe CommentsController do
  let (:user) { create(:user) }
  let (:prod) { create(:product) }

  before do
    sign_in_as user
  end

  describe "#create" do
    context "with authorized user" do
      before do
        prod
      end

      it "creates a comment, sends email, redirects" do
        expect_any_instance_of(Product).to receive(:can_comment?).with(user).and_return true
        message_delivery = instance_double(ActionMailer::MessageDelivery)
        expect(OpenMailer).to receive(:send_comment).with(user, "nigeltufnel@stonehenge.biz", instance_of(Comment), instance_of(String)).and_return message_delivery
        expect(message_delivery).to receive(:deliver_later)

        post :create, to: "nigeltufnel@stonehenge.biz", comment: {user_id: user.id, commentable_id: prod.id, commentable_type: "Product"}

        expect(Comment.count).to eq 1
        expect(flash[:errors]).to be_nil
        expect(response).to redirect_to(product_path(prod))
      end

      it "redirects without error if email address is missing" do
        expect_any_instance_of(Product).to receive(:can_comment?).with(user).and_return true
        expect(OpenMailer).not_to receive(:send_comment)
        post :create, to: "", comment: {user_id: user.id, commentable_id: prod.id, commentable_type: "Product"}
        expect(response).to redirect_to(product_path(prod))
        expect(flash[:errors]).to be_nil
      end

      it "adds flash error if email address is invalid" do
        expect_any_instance_of(Product).to receive(:can_comment?).with(user).and_return true
        expect(OpenMailer).not_to receive(:send_comment)
        post :create, to: "nigeltufnelstonehenge.biz", comment: {user_id: user.id, commentable_id: prod.id, commentable_type: "Product"}
        expect(flash[:errors]).to eq ["Email address is invalid."]
      end
    end

    context "with unauthorized user" do
      it "redirects with flash error" do
        expect_any_instance_of(Product).to receive(:can_comment?).with(user).and_return false
        expect(OpenMailer).not_to receive(:send_comment)

        post :create, to: "nigeltufnelstonehenge.biz", comment: {user_id: user.id, commentable_id: prod.id, commentable_type: "Product"}

        expect(Comment.count).to eq 0
        expect(flash[:errors]).to eq ["You do not have permission to add comments to this item."]
        expect(response).to redirect_to(product_path(prod))
      end
    end
  end

  describe '#bulk_count' do
    it 'gets count for specific items from #get_bulk_count' do
      expect_any_instance_of(described_class).to receive(:get_bulk_count).with({"0" => "99", "1" => "54"}, nil).and_return 2
      post :bulk_count, {"pk" => {"0" => "99", "1" => "54"}}
      expect(response).to be_success
      expect(JSON.parse(response.body)['count']).to eq 2
    end

    it 'gets count for full search update from #get_bulk_count' do
      expect_any_instance_of(described_class).to receive(:get_bulk_count).with(nil, '99').and_return 10
      post :bulk_count, {sr_id: '99'}
      expect(response).to be_success
      expect(JSON.parse(response.body)['count']).to eq 10
    end
  end

  describe '#bulk' do
    it 'calls bulk action runner with bulk comment' do
      bar = OpenChain::BulkAction::BulkActionRunner

      expect(bar).to receive(:process_object_ids)
        .with(instance_of(User),
              ['1', '2'],
              OpenChain::BulkAction::BulkComment,
              {'subject' => 's',
               'body' => 'b',
               'module_type' => 'Order'})

      post :bulk, {'pk' => {'0' => '1', '1' => '2'}, 'module_type' => 'Order', 'subject' => 's', 'body' => 'b'}
      expect(response).to be_success
    end
  end

  describe "#send_email" do
    let (:comment) { Comment.create!(commentable: prod, user: user, subject: "what it's about", body: "what is there to say?") }

    before do
      allow_any_instance_of(Comment).to receive(:publish_comment_create)
    end

    it "sends message if email list contains at least one valid email" do
      expect_any_instance_of(Product).to receive(:can_view?).with(user).and_return true
      message_delivery = instance_double(ActionMailer::MessageDelivery)
      expect(OpenMailer).to receive(:send_comment).with(user, "nigeltufnel@stonehenge.biz", comment, comment_url(comment)).and_return message_delivery
      expect(message_delivery).to receive(:deliver_later)

      post :send_email, {id: comment.id, to: "nigeltufnel@stonehenge.biz"}
      expect(response.body).to eq "OK"
    end

    it "doesn't send message if email list contains an invalid email" do
      expect_any_instance_of(Product).to receive(:can_view?).with(user).and_return true
      expect(OpenMailer).not_to receive(:send_comment)
      post :send_email, {id: comment.id, to: "tufnel@stonehengebiz"}
      expect(response.body).to eq "Email is invalid."
    end

    it "doesn't send message if the email list is blank" do
      expect_any_instance_of(Product).to receive(:can_view?).with(user).and_return true
      expect(OpenMailer).not_to receive(:send_comment)
      post :send_email, {id: comment.id, to: ""}
      expect(response.body).to eq "OK"
    end
  end
end
