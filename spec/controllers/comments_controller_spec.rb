require 'spec_helper'

describe CommentsController do
  before :each do
    u = Factory(:user)
    sign_in_as u
  end
  describe '#bulk_count' do
    it 'should get count for specific items from #get_bulk_count' do
      described_class.any_instance.should_receive(:get_bulk_count).with({"0"=>"99","1"=>"54"}, nil).and_return 2
      post :bulk_count, {"pk" => {"0"=>"99","1"=>"54"}}
      expect(response).to be_success
      expect(JSON.parse(response.body)['count']).to eq 2
    end
    it 'should get count for full search update from #get_bulk_count' do
      described_class.any_instance.should_receive(:get_bulk_count).with(nil, '99').and_return 10
      post :bulk_count, {sr_id:'99'}
      expect(response).to be_success
      expect(JSON.parse(response.body)['count']).to eq 10
    end
  end

  describe '#bulk' do
    it 'should call bulk action runner with bulk comment' do
      bar = OpenChain::BulkAction::BulkActionRunner
      bar.should_receive(:process_object_ids).with(instance_of(User),['1','2'],OpenChain::BulkAction::BulkComment,{'subject'=>'s','body'=>'b','module_type'=>'Order'})
      post :bulk, {'pk'=>{'0'=>'1','1'=>'2'},'module_type'=>'Order','subject'=>'s','body'=>'b'}
      expect(response).to be_success
    end
  end
end
