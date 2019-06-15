describe OpenChain::Validations::Password::PreviousPasswordValidator do
  let!(:user) { Factory.create(:user) }

  before do
    passwords = ["password1", "password2", "password3", "password4", "password5"]

    [5, 10, 15, 20, 25].each_with_index do |time_ago, index|
      UserPasswordHistory.create! do |uph|
        uph.user_id = user.id
        uph.hashed_password = user.encrypt_password(user.password_salt, passwords[index])
        uph.password_salt = user.password_salt
        uph.created_at = uph.updated_at = time_ago.minutes.ago
      end
    end
  end

  it 'returns true if the password has not been used in the last 5 password changes' do
    password = 'notausedpassword'

    expect(described_class.valid_password?(user, password)).to be true
  end

  it 'sets an error if the password has been used in the last 5 password changes' do
    password = 'password1'

    expect(described_class.valid_password?(user, password)).to be false
    expect(user.errors[:password]).to include('cannot be the same as the last 5 passwords')
  end
end