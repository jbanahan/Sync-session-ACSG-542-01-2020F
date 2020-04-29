describe OpenChain::AntiVirus::AntiVirusRegistry do

  class FakeAntiVirus
    def self.safe? file
      false
    end
  end

  subject { described_class }

  describe "check_validity" do
    it "validates that the registered class answers to safe? method" do
      expect(subject.check_validity FakeAntiVirus).to eq true
    end

    it "errors if class doesn't implement safe? method" do
      expect { subject.check_validity Object }.to raise_error "Object must respond to the following methods to be registered as a AntiVirusScanner: safe?."
    end
  end

  describe "safe?" do
    around :each do |ex|
      # Make sure to clear / restore any registered av objects
      # Since AV is hardwired into the paperclip stuff now, I don't want to have every single
      # test have to set up an av.  Instead, we'll just do this here in this one place
      # to accomodate the testing.
      registered_av = OpenChain::AntiVirus::AntiVirusRegistry.registered
      OpenChain::AntiVirus::AntiVirusRegistry.clear
      begin
        ex.run
      ensure
        OpenChain::AntiVirus::AntiVirusRegistry.clear
        registered_av.each {|av| OpenChain::AntiVirus::AntiVirusRegistry.register registered_av }
      end
    end

    before :each do
      subject.register FakeAntiVirus
    end

    it "uses registered class to evaluate object" do
      expect(FakeAntiVirus).to receive(:safe?).with("File").and_return true
      expect(subject.safe? "File").to eq true
    end
  end
end