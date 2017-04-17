require 'spec_helper'

describe CommentsController do
  before :each do
    @u = Factory(:user)
    sign_in_as @u
  end
  describe "#create", :disable_delayed_jobs do
    before do
      @prod = Factory(:product)
    end

    context "with authorized user" do
      before do
        expect_any_instance_of(Product).to receive(:can_comment?).with(@u).and_return true
      end

      it "creates a comment, sends email, redirects" do
        post :create, to: "nigeltufnel@stonehenge.biz", comment: {user_id: @u.id, commentable_id: @prod.id, commentable_type: "Product"}

        expect(Comment.count).to eq 1
        expect(flash[:errors]).to be_nil
        expect(ActionMailer::Base.deliveries.count).to eq 1
        expect(response).to redirect_to(product_path(@prod))
      end
      it "redirects without error if email address is missing" do
        post :create, to: "", comment: {user_id: @u.id, commentable_id: @prod.id, commentable_type: "Product"}
        expect(ActionMailer::Base.deliveries.count).to eq 0
        expect(response).to redirect_to(product_path(@prod))
        expect(flash[:errors]).to be_nil
      end

      it "adds flash error if email address is invalid" do
        post :create, to: "nigeltufnelstonehenge.biz", comment: {user_id: @u.id, commentable_id: @prod.id, commentable_type: "Product"}
        expect(ActionMailer::Base.deliveries.count).to eq 0
        expect(flash[:errors]).to eq ["Email address is invalid."]
      end
    end

    context "with unauthorized user" do
      it "redirects with flash error" do
        expect_any_instance_of(Product).to receive(:can_comment?).with(@u).and_return false

        post :create, to: "nigeltufnelstonehenge.biz", comment: {user_id: @u.id, commentable_id: @prod.id, commentable_type: "Product"}

        expect(ActionMailer::Base.deliveries.count).to eq 0
        expect(Comment.count).to eq 0
        expect(flash[:errors]).to eq ["You do not have permission to add comments to this item."]
        expect(response).to redirect_to(product_path(@prod))
      end
    end
  end

  describe '#bulk_count' do
    it 'should get count for specific items from #get_bulk_count' do
      expect_any_instance_of(described_class).to receive(:get_bulk_count).with({"0"=>"99","1"=>"54"}, nil).and_return 2
      post :bulk_count, {"pk" => {"0"=>"99","1"=>"54"}}
      expect(response).to be_success
      expect(JSON.parse(response.body)['count']).to eq 2
    end
    it 'should get count for full search update from #get_bulk_count' do
      expect_any_instance_of(described_class).to receive(:get_bulk_count).with(nil, '99').and_return 10
      post :bulk_count, {sr_id:'99'}
      expect(response).to be_success
      expect(JSON.parse(response.body)['count']).to eq 10
    end
  end

  describe '#bulk' do
    it 'should call bulk action runner with bulk comment' do
      bar = OpenChain::BulkAction::BulkActionRunner
      expect(bar).to receive(:process_object_ids).with(instance_of(User),['1','2'],OpenChain::BulkAction::BulkComment,{'subject'=>'s','body'=>'b','module_type'=>'Order'})
      post :bulk, {'pk'=>{'0'=>'1','1'=>'2'},'module_type'=>'Order','subject'=>'s','body'=>'b'}
      expect(response).to be_success
    end
  end

  describe "#send_email", :disable_delayed_jobs do
    before :each do
      prod = Factory(:product)
      allow_any_instance_of(Comment).to receive(:publish_comment_create)
      @comment = Comment.create!(:commentable => prod, :user => @u, :subject => "what it's about", :body => "what is there to say?")
      expect_any_instance_of(Product).to receive(:can_view?).with(@u).and_return true
    end

    it "sends message if email list contains at least one valid email" do
      post :send_email, {id: @comment.id, to: "tufnel@stonehenge.biz"}
      expect(response.body).to eq "OK"
      expect(ActionMailer::Base.deliveries.count).to eq 1
      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ["tufnel@stonehenge.biz"]
      expect(mail.subject).to eq "[VFI Track] what it's about"
    end

    it "doesn't send message if email list contains an invalid email" do
      post :send_email, {id: @comment.id, to: "tufnel@stonehengebiz"}
      expect(ActionMailer::Base.deliveries.count).to eq 0
      expect(response.body).to eq "Email is invalid."
    end

    it "doesn't send message if the email list is blank" do
      post :send_email, {id: @comment.id, to: ""}
      expect(ActionMailer::Base.deliveries.count).to eq 0
      expect(response.body).to eq "OK"
    end
  end
end
