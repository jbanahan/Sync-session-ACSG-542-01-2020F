describe OpenChain::Validations::Password::PreviousPasswordValidator do
  let!(:user) { create(:user) }

  before do
    multiples_of_five = (1..130).select { |i| i % 5 == 0 }
    multiples_of_five.each_with_index do |time_ago, index|
      UserPasswordHistory.create! do |uph|
        uph.user_id = user.id
        uph.hashed_password = user.encrypt_password(user.password_salt, "password#{index}")
        uph.password_salt = user.password_salt
        uph.created_at = uph.updated_at = time_ago.minutes.ago
      end
    end
  end

  it 'returns true if the password has not been used in the last 24 password changes' do
    expect(described_class.valid_password?(user, 'password25')).to be true
  end

  it 'sets an error if the password has been used in the last 24 password changes' do
    expect(described_class.valid_password?(user, 'password23')).to be false
    expect(user.errors[:password]).to include('cannot be the same as the last 24 passwords')
  end
end