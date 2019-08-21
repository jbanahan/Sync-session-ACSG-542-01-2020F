describe OpenChain::Validations::Password::PasswordLengthValidator do
  let!(:user) { Factory.build(:user) }

  it 'is valid if the password is at least 8 characters in length and user is not an admin' do
    expect(user).to receive(:admin?).and_return false

    expect(described_class.valid_password?(user, '12345678')).to be true
    expect(user.errors[:password]).to eq []
  end

  it 'is valid if the password is at least 16 characters in length and user is an admin' do
    expect(user).to receive(:admin?).and_return true

    expect(described_class.valid_password?(user, '1234567812345678')).to be true
    expect(user.errors[:password]).to eq []
  end

  it 'is not valid if the password is less than 8 characters and user is not an admin' do
    expect(user).to receive(:admin?).and_return false

    expect(described_class.valid_password?(user, '1234567')).to be false
    expect(user.errors[:password]).to include('must be at least 8 characters long')
  end

  it 'is not valid if the password is less than 16 characters and user is an admin' do
    expect(user).to receive(:admin?).and_return true

    expect(described_class.valid_password?(user, '123456781234567')).to be false
    expect(user.errors[:password]).to include('must be at least 16 characters long')
  end

end