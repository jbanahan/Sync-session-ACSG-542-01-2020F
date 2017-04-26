require 'spec_helper'

describe OpenChain::Validations::Password::PasswordAgePoller do
  before do
    @not_old_password = Factory.create(:user, password_changed_at: Time.zone.now)
    @old_password = Factory.create(:user, password_changed_at: 90.days.ago)
  end

  describe '#expired_passwords' do
    it 'finds password reset dates that are older than the given number of days' do
      expect(subject.expired_passwords("90")).to eq([@old_password])
    end

    it 'does not pull password reset dates that are less than the given number of days' do
      expect(subject.expired_passwords("90")).to_not include(@not_old_password)
    end
  end

  describe '#run' do
    it 'sets password_expired on all expired passwords' do
      subject.run("90")
      @old_password.reload
      @not_old_password.reload

      expect(@old_password.password_expired).to be true
      expect(@not_old_password.password_expired).to be false
    end
  end
end