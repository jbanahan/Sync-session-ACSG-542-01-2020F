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
end
