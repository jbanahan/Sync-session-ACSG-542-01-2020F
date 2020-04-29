describe OpenChain::GpgIntegrationClientParserSupport do

  subject {
    Class.new do
      include OpenChain::GpgIntegrationClientParserSupport
    end
  }

  describe "decrypt" do
    it "utilizes GPG to decrypt data" do
      expect(OpenChain::GPG).to receive(:decrypt_io) do |input, output, secrets_key|
        expect(secrets_key).to eq "secrets"
        expect(input.read).to eq "encrypted"

        output.write 'decrypted'
        nil
      end

      expect(subject.decrypt("encrypted", "secrets")).to eq "decrypted"
    end

    it "uses given IO object for input, instead of creating a buffer" do
      io = StringIO.new "encrypted"

      expect(OpenChain::GPG).to receive(:decrypt_io).with(io, instance_of(StringIO), "secrets")

      subject.decrypt(io, "secrets")
    end
  end

  describe "discover_gpg_key" do
    it "uses parameters from opts variable" do
      expect(subject.discover_gpg_key({gpg_secrets_key: "secrets"})).to eq("secrets")
    end

    it "uses parameters from gpg_secrets_key method if opts has a blank `private_key` key" do
      opts = {gpg_secrets_key: ""}
      expect(subject).to receive(:gpg_secrets_key).with(opts).and_return("secrets")
      expect(subject.discover_gpg_key(opts)).to eq("secrets")
    end

    it "uses parameters from gpg_parameters method if opts has a missing `private_key` key" do
      opts = {}
      expect(subject).to receive(:gpg_secrets_key).with(opts).and_return("secrets")
      expect(subject.discover_gpg_key(opts)).to eq("secrets")
    end
  end

  describe "pre_process_data" do
    it "decrypts data if encrypted opt is true" do
      expect(subject).to receive(:discover_gpg_key).and_return("secret")
      expect(subject).to receive(:decrypt).with("encrypted", "secret").and_return "decrypted"

      expect(subject.pre_process_data "encrypted", {encrypted: true}).to eq "decrypted"
    end

    it "decrypts data if opts[:key] has a pgp file extension" do
      expect(subject).to receive(:discover_gpg_key).and_return("secret")
      expect(subject).to receive(:decrypt).with("encrypted", "secret").and_return "decrypted"

      expect(subject.pre_process_data "encrypted", {key: "file.txt.pgp"}).to eq "decrypted"
    end

    it "raises an error if invalid GPG parameters are returned" do
      expect(subject).to receive(:discover_gpg_key).and_return(nil)
      expect {subject.pre_process_data "encrypted", {encrypted: true}}.to raise_error ArgumentError, "Missing gpg configuration for ''"
    end

    it "returns given data object if data is not encrypted" do
      o = Object.new

      expect(subject.pre_process_data o, {}).to eq o
    end
  end

end