require 'spec_helper'

describe OpenChain::Validations::Password::PasswordLengthValidator do
  let!(:user) { Factory.build(:user) }

  it 'is valid if the password is at least 8 characters in length' do
    password = '12345678'
    user.password = password

    expect(described_class.valid_password?(user, password)).to be true
  end

  it 'is not valid if the password is less than 8 characters' do
    password = '1234567'
    user.password = password

    expect(described_class.valid_password?(user, password)).to be false
    expect(user.errors[:password]).to include('must be at least 8 characters long')
  end
end