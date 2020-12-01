describe PasswordResetsHelper do
  let!(:user) { FactoryBot(:user) }
  describe '#requires_old_password?' do
    it 'does not require the old password when neither password_locked nor password_expired are present' do
      user.update_attributes(password_locked: false, password_expired: false)
      expect(helper.requires_old_password?(user)).to be_falsey
    end
    it 'does not require the old password when password is expired and forgot_password is set' do
      user.password_expired = true
      user.forgot_password = true
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
