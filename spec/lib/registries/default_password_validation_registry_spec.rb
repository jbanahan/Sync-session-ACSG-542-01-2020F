describe OpenChain::Registries::DefaultPasswordValidationRegistry do

  subject { described_class }

  describe "child_registries" do
    it "uses expected child services" do
      expect(subject.child_services).to eq [
          OpenChain::Validations::Password::PasswordLengthValidator, OpenChain::Validations::Password::UsernameNotPasswordValidator,
          OpenChain::Validations::Password::PasswordComplexityValidator, OpenChain::Validations::Password::PreviousPasswordValidator
        ]
    end
  end

end