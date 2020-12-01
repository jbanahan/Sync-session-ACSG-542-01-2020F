describe OpenChain::CustomHandler::LumberLiquidators::LumberPasswordLengthValidator do

  let!(:user) { FactoryBot.build(:user) }

  it 'is valid if the password is at least 8 characters in length' do
    expect(user).to_not receive(:admin?)

    expect(described_class.valid_password?(user, '12345678')).to be true
  end

  it 'is not valid if the password is less than 8 characters' do
    expect(user).to_not receive(:admin?)

    expect(described_class.valid_password?(user, '1234567')).to be false
    expect(user.errors[:password]).to include('must be at least 8 characters long')
  end

end