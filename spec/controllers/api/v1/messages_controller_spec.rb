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

  describe '#mark_as_read' do
    it "should mark message as read" do
      m = @u.messages.create!(subject:'M1',body:'my body')

      post :mark_as_read, id: m.id

      expect(response).to be_success

      expect(JSON.parse(response.body)['message']['subject']).to eq 'M1'
      m.reload
      expect(m).to be_viewed
    end
    it "should 404 if message not found for current user" do
      m = Factory(:user).messages.create!(subject:'X')
      
      post :mark_as_read, id: m.id

      expect(response.status).to eq 404

    end
  end

  describe '#create' do
    it "should restrict to admin" do
      expect {post :create, {message: {user_id:@u.id, subject: 'hello'}}}.to_not change(Message,:count)
      expect(response.status).to eq 403
    end
    it "should post message to user" do
      @u.admin = true
      @u.save!

      expect {post :create, {message: {user_id:@u.id, subject: 'hello', body:'body'}}}.to change(Message,:count).by(1)
      expect(response).to be_success

      m = Message.first
      expect(m.subject).to eq 'hello'
      expect(m.body).to eq 'body'
      expect(m.user).to eq @u
    end
  end
end