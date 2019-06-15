describe OpenChain::Registries::RegistrySupport do

  subject {
    Class.new do 
      include OpenChain::Registries::RegistrySupport

      def registered
        raise "Mock me"
      end
    end.new
  }

  describe "check_registration_validity" do
    it "accepts classes that implement all required methods" do
      expect(subject.check_registration_validity String, "StringRegistry", [:to_s, :freeze]).to eq true
    end

    it "rejects classes that do not implement all methods" do
      expect{ subject.check_registration_validity String, "StringRegistry", [:to_s, :wut, :lol] }.to raise_error "String must respond to the following methods to be registered as a StringRegistry: wut, lol."
    end
  end

  describe "evaluate_all_registered" do
    let (:registered) {
      ["abc", "bcd", "cde", nil]
    }

    it "calls a method on every registed object that responds to the method" do
      expect(subject).to receive(:registered).and_return registered

      expect(subject.evaluate_all_registered :upcase).to eq ["ABC", "BCD", "CDE"]
    end

    it "passes parameters to method" do
      expect(subject).to receive(:registered).and_return registered

      expect(subject.evaluate_all_registered :slice, 0, 1).to eq ["a", "b", "c"]
    end
  end

  describe "evaluate_registered_permission" do

    def register
      Class.new do
        def initialize val
          @val = val
        end

        def permission arg1
          @val
        end
      end
    end

    it "returns true if all registred methods return true" do
      registered_1 = register.new(true)
      registered_2 = register.new(true)
      expect(registered_1).to receive(:permission).with("arg").and_return true
      expect(registered_2).to receive(:permission).with("arg").and_return true

      expect(subject).to receive(:registered).and_return [registered_1, registered_2]
      expect(subject.evaluate_registered_permission :permission, "arg").to eq true
    end

    it "short-circuits and returns false if any permission fails" do
      registered_1 = register.new(false)
      registered_2 = register.new(true)
      expect(registered_1).to receive(:permission).with("arg").and_return false
      expect(registered_2).not_to receive(:permission)

      expect(subject).to receive(:registered).and_return [registered_1, registered_2]
      expect(subject.evaluate_registered_permission :permission, "arg").to eq false
    end

    it "skips registered objects that don't respond to the method" do
      expect(subject).to receive(:registered).and_return [register.new(true), register.new(true), "Test", register.new(true)]
      expect(subject.evaluate_registered_permission :permission, "arg").to eq true
    end
  end
end

