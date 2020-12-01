describe Api::V1::MessagesController do
  let(:user) { FactoryBot(:user) }

  before do
    allow_api_access user
  end

  describe '#index' do
    it 'gets message list' do
      Timecop.freeze(Time.zone.now) do
        m1 = user.messages.create!(subject: 'M1', body: 'my body', created_at: 3.minutes.ago)
        m2 = user.messages.create!(subject: 'm2', body: 'mb2', viewed: true, created_at: 2.minutes.ago)

        expected = {'messages' => [
          {'id' => m2.id, 'subject' => 'm2', 'body' => 'mb2', 'viewed' => true},
          {'id' => m1.id, 'subject' => 'M1', 'body' => 'my body'}
        ]}

        get :index

        expect(response).to be_success

        expect(JSON.parse(response.body)).to eq expected
      end
    end
  end

  describe '#count' do
    it "gets message count by user id" do
      user.messages.create!(subject: 'M1', body: 'my body')

      get :count, user_id: user.id

      expect(response).to be_success
      expected = {'message_count' => 1}
      expect(JSON.parse(response.body)).to eq expected
    end
  end

  describe '#mark_as_read' do
    it "marks message as read" do
      m = user.messages.create!(subject: 'M1', body: 'my body')

      post :mark_as_read, id: m.id

      expect(response).to be_success

      expect(JSON.parse(response.body)['message']['subject']).to eq 'M1'
      m.reload
      expect(m).to be_viewed
    end

    it "404S if message not found for current user" do
      m = FactoryBot(:user).messages.create!(subject: 'X')

      post :mark_as_read, id: m.id

      expect(response.status).to eq 404

    end
  end

  describe '#create' do
    it "restricts to admin" do
      expect {post :create, {message: {user_id: user.id, subject: 'hello'}}}.not_to change(Message, :count)
      expect(response.status).to eq 403
    end

    it "posts message to user" do
      user.admin = true
      user.save!

      expect {post :create, {message: {user_id: user.id, subject: 'hello', body: 'body'}}}.to change(Message, :count).by(1)
      expect(response).to be_success

      m = Message.first
      expect(m.subject).to eq 'hello'
      expect(m.body).to eq 'body'
      expect(m.user).to eq user
    end
  end
end