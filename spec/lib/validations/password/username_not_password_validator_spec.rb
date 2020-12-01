describe OpenChain::Validations::Password::UsernameNotPasswordValidator do
  let!(:user) { FactoryBot.build(:user) }

  it 'returns true if the password is not the username' do
    user.password = password = 'notausername'

    expect(described_class.valid_password?(user, password)).to be true
  end

  it 'returns false and sets an error message if the password is the username' do
    user.password = password = user.username

    expect(described_class.valid_password?(user, password)).to be false
    expect(user.errors[:password]).to include('cannot be the same as the username')
  end
end