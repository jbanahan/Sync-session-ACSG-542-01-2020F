require 'spec_helper'

describe OpenChain::UserSupport::FailedPasswordHandler do
  let!(:user) { Factory.create(:user) }
  subject { OpenChain::UserSupport::FailedPasswordHandler }

  describe '#call' do
    it "increments failed login count" do
      subject.call(user)
      expect(user.failed_logins).to eql(1)
      expect(user.password_locked?).to eq false
    end

    it "sets password_locked to true if failed login count is 5 or more" do
      user.update_attribute(:failed_logins, 4)
      subject.call(user)
      expect(user.password_locked).to eq true
    end
  end
end