describe OpenChain::Validations::Password::PasswordComplexityValidator do
  let!(:user) { create.build(:user) }

  describe '.has_symbol?' do
    it 'returns true if string contains symbol' do
      password = user.password = 'Ab1@'

      expect(described_class.has_symbol?(password)).to be true
    end

    it 'returns false if string does not contain a symbol' do
      password = user.password = 'Ab1c'

      expect(described_class.has_symbol?(password)).to be false
    end
  end

  describe '.has_uppercase?' do
    it 'returns true if string contains an uppercase letter' do
      password = user.password = 'Ab1'

      expect(described_class.has_uppercase?(password)).to be true
    end

    it 'returns false if string does not contain an uppercase letter' do
      password = user.password = 'ab1'

      expect(described_class.has_uppercase?(password)).to be false
    end
  end

  describe '.has_lowercase?' do
    it 'returns true if string contains a lowercase letter' do
      password = user.password = 'abc'

      expect(described_class.has_lowercase?(password)).to be true
    end

    it 'returns false if string does not contain a lowercase letter' do
      password = user.password = 'ABC'

      expect(described_class.has_lowercase?(password)).to be false
    end
  end

  describe '.has_digit?' do
    it 'returns true if string contains a digit' do
      password = user.password = 'ab1'

      expect(described_class.has_digit?(password)).to be true
    end

    it 'returns false if string does not contain a digit' do
      password = user.password = 'abc'

      expect(described_class.has_digit?(password)).to be false
    end
  end

  it 'is valid if the password contains an upper case letter, a number and a symbol' do
    password = user.password = 'Ab1@'

    expect(described_class.valid_password?(user, password)).to be true
  end

  it 'is valid if 3 of the 4 requirements are valid' do
    password = user.password = "Ab1"

    expect(described_class.valid_password?(user, password)).to be true
  end

  it 'returns an error if requirements are not met' do
    password = user.password = "Abc"
    error = 'must contain 3 of the 4 following characters: upper case letter, lower case letter, number, symbol'

    described_class.valid_password?(user, password)
    expect(user.errors[:password]).to include error
  end
end