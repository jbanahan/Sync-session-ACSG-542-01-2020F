require 'spec_helper'

describe Api::V1::MessagesController do
  before(:each) do
    @u = Factory(:user)
    allow_api_access @u
  end
  describe '#index' do
    it 'should get message list' do
      Timecop.freeze(Time.now) do
        m1 = @u.messages.create!(subject:'M1',body:'my body',created_at:3.minutes.ago)
        m2 = @u.messages.create!(subject:'m2',body:'mb2',viewed:true,created_at:2.minutes.ago)

        expected = {'messages'=>[
          {'id'=>m2.id,'subject'=>'m2','body'=>'mb2','viewed'=>true},
          {'id'=>m1.id,'subject'=>'M1','body'=>'my body'}
        ]}

        get :index

        expect(response).to be_success

        expect(JSON.parse(response.body)).to eq expected
      end
    end
  end

  describe '#count' do
    it "should get message count by user id" do
      @u.messages.create!(subject:'M1',body:'my body')

      get :count, user_id: @u.id

      expect(response).to be_success
      expected = {'message_count'=>1}
      expect(JSON.parse(response.body)).to eq expected
    end
  end
end