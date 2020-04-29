describe SentEmail do
  before(:each) do
    @user = Factory(:user)
    @email_1 = SentEmail.create
    @email_2 = SentEmail.create
  end

  describe "can_view?" do
    it "grants permission to admins" do
      expect(@email_1.can_view? @user).to be_falsey

      @user.admin = true
      expect(@email_1.can_view? @user).to be_truthy
    end
  end

  describe "self.find_can_view" do
    it "shows all records to sys-admins" do
      expect(SentEmail.find_can_view @user).to be_nil

      @user.admin = true
      expect((SentEmail.find_can_view @user).count).to eq 2
    end
  end

  describe "purge" do
    subject { described_class }

    it "removes anything older than given date" do
      email = nil
      Timecop.freeze(Time.zone.now - 1.second) { email = SentEmail.create! }

      subject.purge Time.zone.now

      expect {email.reload}.to raise_error ActiveRecord::RecordNotFound
    end

    it "does not remove items newer than given date" do
      email = nil
      now = Time.zone.now
      Timecop.freeze(now + 1.second) { email = SentEmail.create! }

      subject.purge now

      expect {email.reload}.not_to raise_error
    end
  end
end
