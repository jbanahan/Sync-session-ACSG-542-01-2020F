describe OpenChain::Registries::PasswordValidationRegistry do

  subject { described_class }

  let (:service) {
    Class.new {
      def self.valid_password? user, password
        true
      end
    }
  }

  describe 'register' do

    it 'should register if class implements valid_password?' do
      subject.register service
      expect(subject.registered.to_a).to eq [service]
    end

    it 'should fail if the class doesn\'t implement valid_password?' do
      c = Class.new do
      end

      expect { described_class.register c}.to raise_error(/valid_password/)
      expect(described_class.registered.to_a).to be_empty
    end
  end

  describe "valid_password?" do

    before :each do 
      subject.register service
    end

    it "evaluates valid_password? for all registered objects" do
      u = User.new
      expect(service).to receive(:valid_password?).with(u, "password").and_return true
      expect(subject.valid_password? u, 'password').to eq true
    end
  end
end