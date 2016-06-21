require 'spec_helper'

describe CommentsController do
  before :each do
    u = Factory(:user)
    sign_in_as u
  end
  describe '#bulk_count' do
    it 'should get count for specific items' do
      p = {"pk" => {"0"=>"99","1"=>"54"}}
      post :bulk_count, p
      expect(response).to be_success
      expect(JSON.parse(response.body)['count']).to eq 2
    end
    it 'should get count for full search update' do
      sr = double('search_run')
      sr.should_receive(:total_objects).and_return 10
      SearchRun.should_receive(:find_by_id).with('99').and_return sr
      post :bulk_count, {sr_id:'99'}
      expect(response).to be_success
      expect(JSON.parse(response.body)['count']).to eq 10
    end
  end

  describe '#bulk' do
    it 'should call bulk action runner with bulk comment' do
      bar = OpenChain::BulkAction::BulkActionRunner
      bar.should_receive(:process_object_ids).with(instance_of(User),['1','2'],OpenChain::BulkAction::BulkComment,{'subject'=>'s','body'=>'b','module_type'=>'Order'})
      post :bulk, {'pk'=>['1','2'],'module_type'=>'Order','subject'=>'s','body'=>'b'}
      expect(response).to be_success
    end
  end
end
