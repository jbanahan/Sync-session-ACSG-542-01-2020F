require 'spec_helper'

describe OpenChain::UserSupport::FailedPasswordHandler do
  let!(:user) { Factory.create(:user) }
  subject { OpenChain::UserSupport::FailedPasswordHandler }

  describe '#call' do
    it "increments failed login count" do
      subject.call(user)
      user.reload
      expect(user.failed_logins).to eql(1)
    end

    it "sets password_locked to true if failed login count is 5 or more" do
      user.update_attribute(:failed_logins, 4)
      subject.call(user)
      user.reload
      expect(user.password_locked).to be true
    end
  end
end