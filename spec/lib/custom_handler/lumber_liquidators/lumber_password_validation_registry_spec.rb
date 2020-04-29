describe OpenChain::CustomHandler::LumberLiquidators::LumberPasswordValidationRegistry do

  subject { described_class }

  describe "child_registries" do
    it "uses expected child services" do
      expect(subject.child_services).to eq [
          OpenChain::CustomHandler::LumberLiquidators::LumberPasswordLengthValidator, OpenChain::Validations::Password::UsernameNotPasswordValidator,
          OpenChain::Validations::Password::PasswordComplexityValidator, OpenChain::CustomHandler::LumberLiquidators::LumberPreviousPasswordValidator
        ]
    end
  end

end