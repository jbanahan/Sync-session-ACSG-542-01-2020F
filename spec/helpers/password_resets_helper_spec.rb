require 'spec_helper'

describe PasswordResetsHelper do
  let!(:user) { Factory(:user) }
  describe '#requires_old_password?' do
    it 'does not require the old password if only the confirmation_token is set' do
      user.confirmation_token = '123456'
      user.save!
      expect(helper.requires_old_password?(user)).to be_falsey
    end
    it 'does not require the old password when neither password_locked nor password_expired are present' do
      user.update_attributes(password_locked: false, password_expired: false)
      expect(helper.requires_old_password?(user)).to be_falsey
    end
    it 'does not require the old password when password is expired and confirmation_token is present' do
      # I use a save here because, for some reason, the confirmation_token would not update
      # in an update_attributes call. (Possible mass-assignment restrictions.)
      user.confirmation_token = '123456'
      user.password_expired = true
      user.save!
      expect(helper.requires_old_password?(user)).to be_falsey
    end
    it 'does not require the old password when password is expired AND password is locked' do
      user.update_attributes(password_locked: true, password_expired: true)
      expect(helper.requires_old_password?(user)).to be_falsey
    end
    it 'does not require the old password when password is locked' do
      user.update_attribute(:password_locked, true)
      expect(helper.requires_old_password?(user)).to be_falsey
    end
    it 'requires the old password when password is expired' do
      user.update_attribute(:password_expired, true)
      expect(helper.requires_old_password?(user)).to be_truthy
    end
  end
end
