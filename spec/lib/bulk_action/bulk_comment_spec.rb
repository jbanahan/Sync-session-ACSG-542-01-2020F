describe OpenChain::BulkAction::BulkComment do
  describe '#act' do
    before :each do
      @ord = FactoryBot(:order)
      @u = FactoryBot(:master_user, order_comment:true, order_view:true)
      @bpl = FactoryBot(:bulk_process_log)
    end
    it 'should comment on object' do
      opts = {'module_type'=>'Order', 'subject'=>'sub', 'body'=>'bod'}
      expect {described_class.act @u, @ord.id.to_s, opts, @bpl, 99}.to change(Comment, :count).from(0).to(1)
      c = Comment.first
      expect(c.commentable).to eq @ord
      expect(c.subject).to eq 'sub'
      expect(c.body).to eq 'bod'
      expect(c.user).to eq @u
      expect(@bpl.change_records.count).to eq 1
      expect(@bpl.change_records.first.record_sequence_number).to eq 99
    end
    it 'should write error if user cannot comment' do
      allow(@ord).to receive(:can_comment?).and_return false
      expect(Order).to receive(:find).with(@ord.id.to_s).and_return @ord # need exact object to use stubbed can_comment?
      opts = {'module_type'=>'Order', 'subject'=>'sub', 'body'=>'bod'}
      expect {described_class.act @u, @ord.id.to_s, opts, @bpl, 99}.to_not change(Comment, :count)
      expect(@bpl.change_records.count).to eq 1
      cr = @bpl.change_records.first
      expect(cr).to be_failed
    end
  end
end
