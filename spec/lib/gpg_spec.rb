describe OpenChain::GPG do

  # There's little point in testing decrypt without encrypt
  
  # The public / private keys are in spec/fixtures/files
  # There's two sets...one w/ a passphrase and one without.
  describe "decrypt_file" do

    it "decrypts a file with a standard public/private gpg keypair" do
      gpg = OpenChain::GPG.new 'spec/fixtures/files/vfitrack.gpg.key', 'spec/fixtures/files/vfitrack.gpg.private.key'

      Tempfile.open(["test", ".txt"]) do |f|
        # Yep, 'passphrase' is the passphrase - secure key, huh!
        gpg.decrypt_file('spec/fixtures/files/passphrase-encrypted.gpg', f.path, 'passphrase')
        expect(IO.read(f.path)).to eq IO.read('spec/fixtures/files/passphrase-cleartext.txt')
      end
    end

    it "decrypts a file with a passphraseless gpg keypair" do
      gpg = OpenChain::GPG.new 'spec/fixtures/files/vfitrack-passphraseless.gpg.key', 'spec/fixtures/files/vfitrack-passphraseless.gpg.private.key'

      Tempfile.open(["test", ".txt"]) do |f|
        gpg.decrypt_file('spec/fixtures/files/passphraseless-encrypted.gpg', f.path)
        expect(IO.read(f.path)).to eq IO.read('spec/fixtures/files/passphraseless-cleartext.txt')
      end
    end

    it "can use a file object for input / output destinations" do
      gpg = OpenChain::GPG.new 'spec/fixtures/files/vfitrack-passphraseless.gpg.key', 'spec/fixtures/files/vfitrack-passphraseless.gpg.private.key'

      in_file = File.open("spec/fixtures/files/passphraseless-encrypted.gpg", "rb")
      begin
        Tempfile.open(["test", ".txt"]) do |f|
          gpg.decrypt_file(in_file, f)
          expect(IO.read(f.path)).to eq IO.read('spec/fixtures/files/passphraseless-cleartext.txt')
        end
      ensure
        in_file.close
      end
    end

    it "can use a pathname object for input / output destinations" do
      gpg = OpenChain::GPG.new 'spec/fixtures/files/vfitrack-passphraseless.gpg.key', 'spec/fixtures/files/vfitrack-passphraseless.gpg.private.key'

      pathname = Pathname.new("spec/fixtures/files/passphraseless-encrypted.gpg")
      Tempfile.open(["test", ".txt"]) do |f|
        gpg.decrypt_file(pathname, Pathname.new(f.path))
        expect(IO.read(f.path)).to eq IO.read('spec/fixtures/files/passphraseless-cleartext.txt')
      end
    end

    it "errors if gpg binary path is invalid" do
      expect(described_class).to receive(:gpg_binary).and_return "not_gpg"

      gpg = OpenChain::GPG.new 'spec/fixtures/files/vfitrack.gpg.key', 'spec/fixtures/files/vfitrack.gpg.private.key'

      Tempfile.open(["test", ".txt"]) do |f|
        # Yep, 'passphrase' is the passphrase - secure key, huh!
        expect { gpg.decrypt_file('spec/fixtures/files/passphrase-encrypted.gpg', f.path, 'passphrase') }.to raise_error "GPG binary path must point to a gpg executable."
      end
    end
  end

  describe "encrypt_file" do
    it "encrypts a file" do
      # Only need the public key for encrypting
      gpg = OpenChain::GPG.new 'spec/fixtures/files/vfitrack-passphraseless.gpg.key'

      Tempfile.open(["file", ".txt"]) do |f|
        gpg.encrypt_file 'spec/fixtures/files/passphraseless-cleartext.txt', f.path

        Tempfile.open(["decrypt", ".txt"]) do |decrypt_file|
          decrypt_gpg = OpenChain::GPG.new 'spec/fixtures/files/vfitrack-passphraseless.gpg.key', 'spec/fixtures/files/vfitrack-passphraseless.gpg.private.key'
          decrypt_gpg.decrypt_file(f, decrypt_file)

          expect(IO.read(decrypt_file.path)).to eq IO.read 'spec/fixtures/files/passphraseless-cleartext.txt'
        end
      end
    end

    it "encrypts a file using file objects" do
      # Only need the public key for encrypting
      gpg = OpenChain::GPG.new 'spec/fixtures/files/vfitrack-passphraseless.gpg.key'

      file = File.open('spec/fixtures/files/passphraseless-cleartext.txt', "rb")
      begin
        Tempfile.open(["file", ".txt"]) do |f|
          gpg.encrypt_file file, f

          Tempfile.open(["decrypt", ".txt"]) do |decrypt_file|
            decrypt_gpg = OpenChain::GPG.new 'spec/fixtures/files/vfitrack-passphraseless.gpg.key', 'spec/fixtures/files/vfitrack-passphraseless.gpg.private.key'
            decrypt_gpg.decrypt_file(f, decrypt_file)

            expect(IO.read(decrypt_file.path)).to eq IO.read 'spec/fixtures/files/passphraseless-cleartext.txt'
          end
        end
      ensure
        file.close
      end
    end
  end

  describe "decrypt_io" do
    subject { described_class }
    let (:private_key) { 'spec/fixtures/files/vfitrack-passphraseless.gpg.private.key' }
    let (:gpg_encryptor) { OpenChain::GPG.new 'spec/fixtures/files/vfitrack-passphraseless.gpg.key', nil }

    let (:plaintext_file) {
      f = Tempfile.open(["plaintext", ".txt"])
      f.binmode
      f << "encrypted\n"
      f.flush

      f
    }

    let (:encrypted_file) {
      f = Tempfile.open(["encrypted", ".txt.gpg"])
      gpg_encryptor.encrypt_file plaintext_file.path, f.path
      f.rewind

      f
    }

    let (:encrypted_data) {
      encrypted_file.read
    }

    let (:encrypted_io) { StringIO.new encrypted_data }

    let (:secrets) { 
      s = {
        'gpg' => {
          'gpg_key' => {
            "private_key_path" => 'spec/fixtures/files/vfitrack-passphraseless.gpg.private.key',
            "passphrase" => nil
          }
        }
      }
    }

    after :each do
      encrypted_file.close!
      plaintext_file.close!
    end

    it "decrypts data from an IO-like object to another IO-like object" do 
      expect(MasterSetup).to receive(:secrets).and_return secrets
      output = StringIO.new
      subject.decrypt_io encrypted_io, output, 'gpg_key'
      output.rewind
      expect(output.read).to eq "encrypted\n"
    end

    it "decrypts data from an IO-like object to another IO-like object, using a passphrase" do 
      secrets["gpg"]["gpg_key"]["passphrase"] = "Open Sesame"
      expect(MasterSetup).to receive(:secrets).and_return secrets

      # We're just bypassing the actual decryption here to make sure the passphrase is actually being utilized as expected
      expect_any_instance_of(subject).to receive(:decrypt_file) do |instance, input_path, output_path, passphrase|
        expect(passphrase).to eq "Open Sesame"

        File.open(output_path, "w") do |output|
          output << "encrypted\n"
        end
      end

      output = StringIO.new
      subject.decrypt_io encrypted_io, output, 'gpg_key'
      output.rewind
      expect(output.read).to eq "encrypted\n"
    end

    it "does not buffer any data internally if Tempfile objects are passed" do
      expect(MasterSetup).to receive(:secrets).and_return secrets

      # The easiest way to see if we're directly using the given File objects is
      # to check if IO.copy_stream is used or not
      expect(IO).not_to receive(:copy_stream)

      Tempfile.open(["output", ".txt"]) do |output|
        output.binmode
        subject.decrypt_io encrypted_file, output, 'gpg_key'

        output.rewind
        expect(output.read).to eq "encrypted\n"
      end
      
    end

    it "raises an error if private key path is not present in secrets" do
      secrets["gpg"]["gpg_key"]["private_key_path"] = ""
      expect(MasterSetup).to receive(:secrets).and_return secrets

      expect { subject.decrypt_io nil, nil, 'gpg_key' }.to raise_error ArgumentError, "Missing 'private_key_path' key in secrets.yml for gpg:gpg_key."
    end
  end

  describe "encrypt_io" do
    subject { described_class }

    let (:secrets) { 
      s = {
        'gpg' => {
          'gpg_key' => {
            "public_key_path" => 'spec/fixtures/files/vfitrack-passphraseless.gpg.key'
          }
        }
      }
    }

    it "encrypts IO data" do
      expect(MasterSetup).to receive(:secrets).and_return secrets

      data = StringIO.new "plaintext"
      data.rewind

      encrypted = StringIO.new

      subject.encrypt_io data, encrypted, 'gpg_key' 

      expect(encrypted.pos).to be > 0
      encrypted.rewind
      encrypted_data = encrypted.read
      expect(encrypted_data).not_to eq "plaintext"
    end

    it "does not buffer File IO" do
      expect(MasterSetup).to receive(:secrets).and_return secrets
      # The easiest way to see if we're directly using the given File objects is
      # to check if IO.copy_stream is used or not
      expect(IO).not_to receive(:copy_stream)

      encrypted_data = nil

      Tempfile.open(["input", "in"]) do |in_file|
        in_file << "plaintext"
        in_file.rewind

        Tempfile.open(["output", "out"]) do |out_file|
          subject.encrypt_io in_file, out_file, "gpg_key"  

          out_file.rewind
          encrypted_data = out_file.read
        end
      end

      expect(encrypted_data).not_to be_nil
      expect(encrypted_data).not_to eq "plaintext"
      # We can examine the first couple chars of the file to determine if the data looks
      # like it's actually encrypted (in this case, it's an RSA key encryption, and I
      # know all files encrypted like that are going to start with these bytes)
      expect(encrypted_data.bytes.take(3)).to eq [132, 140, 3]
    end
  end
end
