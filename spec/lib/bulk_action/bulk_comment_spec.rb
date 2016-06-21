require 'spec_helper'

describe OpenChain::BulkAction::BulkComment do
  describe '#act' do
    before :each do
      @ord = Factory(:order)
      @u = Factory(:master_user,order_comment:true,order_view:true)
    end
    it 'should comment on object' do
      opts = {'module_type'=>'Order','subject'=>'sub','body'=>'bod'}
      expect {described_class.act @u, @ord.id.to_s, opts}.to change(Comment,:count).from(0).to(1)
      c = Comment.first
      expect(c.commentable).to eq @ord
      expect(c.subject).to eq 'sub'
      expect(c.body).to eq 'bod'
      expect(c.user).to eq @u
    end
    it 'should raise error if user cannot comment' do
      @ord.stub(:can_comment?).and_return false
      expect {described_class.act @u, @ord.id.to_s, opts}.to raise_error
      expect(Comment.count).to eq 0
    end
  end
end
