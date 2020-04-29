# This is mostly just a wrapper around a wrapper around the gpg binary.
# This class is primarily here to facilitate ease of testing gpg uses
# and to insulate from any shifting of the GPG implementation we may need to do.
module OpenChain; class GPG

  # This method provides abstractions to be able to utilize GPG to decrypted an encrypted
  # IO object. Because this decryption scheme involves utilize the gpg command line program
  # and feeding file paths to it, the abstraction utilizes tempfiles for the data (unless given
  # File IO objects), thus the process is not particularly performant.
  #
  # It relies on drawing all data about the GPG private key from a key value that points to a key
  # below a primary 'gpg' key in the secrets.yml file.  A valid set up would look like this.
  # public_key_path is only needed for encryption (not decryption).
  #
  #  gpg:
  #    some_key:
  #      private_key_path: config/some_key.asc
  #      passphrase: jklasdfj1u9012jay8123l
  #      public_key: config/some_public_key.asc
  #
  #
  # NOTE:
  # It looks like it's possible to utilize stdin / stdout with the gpg binary (which should allow for
  # piping those directly from / to the given IO objects), but doing so would involve heavy
  # refactoring of the internals of this class which is out of scope at the moment, though probably
  # a fun little project to consider in the future.
  #
  def self.decrypt_io encrypted_input, decrypted_output, gpg_secrets_key
    key_data = get_key_data(gpg_secrets_key, private_key_required: true)

    gpg = self.new(nil, key_data['private_key_path'])

    input_buffer = nil
    output_buffer = nil
    begin
      input_buffer = possibly_make_tempfile(encrypted_input, ["encrypted", "in"])
      output_buffer = possibly_make_tempfile(decrypted_output, ["decrypted", "out"])
      # If we are buffering the input internally, we need to copy the data from the given input to our buffer
      if input_buffer[:temp]
        IO.copy_stream(encrypted_input, input_buffer[:io])
        input_buffer[:io].flush
      end

      # Do the actual decryption
      gpg.decrypt_file input_buffer[:io].path, output_buffer[:io].path, key_data['passphrase']

      # If we're buffering the output internally, then copy the buffered data to the actual output stream
      if output_buffer[:temp]
        output_buffer[:io].rewind
        IO.copy_stream output_buffer[:io], decrypted_output
      end
    ensure
      # Make sure to close the input/output buffers if we provided our own internally here
      begin
        input_buffer[:io].close! if input_buffer.try(:[], :temp)
      ensure
        output_buffer[:io].close! if output_buffer.try(:[], :temp)
      end
    end

    nil
  end

  # This method provides abstractions to be able to utilize GPG to encrypted data in an
  # IO object. Because this decryption scheme involves utilize the gpg command line program
  # and feeding file paths to it, the abstraction utilizes tempfiles for the data (unless given
  # File IO objects), thus the process is not particularly performant.
  #
  # It relies on drawing all data about the GPG private key from a key value that points to a key
  # below a primary 'gpg' key in the secrets.yml file.  A valid set up would look like this.
  # public_key_path is only needed for encryption (not decryption).
  #
  #  gpg:
  #    some_key:
  #      public_key_path: config/some_key.asc
  #
  #
  # NOTE:
  # It looks like it's possible to utilize stdin / stdout with the gpg binary (which should allow for
  # piping those directly from / to the given IO objects), but doing so would involve heavy
  # refactoring of the internals of this class which is out of scope at the moment, though probably
  # a fun little project to consider in the future.
  #
  def self.encrypt_io plaintext_input, encrypted_output, gpg_secrets_key
    key_data = get_key_data(gpg_secrets_key, public_key_required: true)
    gpg = self.new(key_data['public_key_path'], nil)

    input_buffer = nil
    output_buffer = nil
    begin
      input_buffer = possibly_make_tempfile(plaintext_input, ["encrypted", "in"])
      output_buffer = possibly_make_tempfile(encrypted_output, ["decrypted", "out"])
      # If we are buffering the input internally, we need to copy the data from the given input to our buffer
      if input_buffer[:temp]
        IO.copy_stream(plaintext_input, input_buffer[:io])
        input_buffer[:io].flush
      end

      # Do the actual decryption
      gpg.encrypt_file input_buffer[:io].path, output_buffer[:io].path

      # If we're buffering the output internally, then copy the buffered data to the actual output stream
      if output_buffer[:temp]
        output_buffer[:io].rewind
        IO.copy_stream output_buffer[:io], encrypted_output
      end
    ensure
      # Make sure to close the input/output buffers if we provided our own internally here
      begin
        input_buffer[:io].close! if input_buffer.try(:[], :temp)
      ensure
        output_buffer[:io].close! if output_buffer.try(:[], :temp)
      end
    end

    nil
  end

  # Gets the key data for the given
  def self.get_key_data gpg_secrets_key, private_key_required: false, public_key_required: false
    key_data = MasterSetup.secrets["gpg"].try(:[], gpg_secrets_key.to_s)
    raise ArgumentError, "Missing gpg configuration for '#{gpg_secrets_key}'" if key_data.nil?
    raise ArgumentError, "Missing 'private_key_path' key in secrets.yml for gpg:#{gpg_secrets_key}." if private_key_required && key_data['private_key_path'].blank?
    raise ArgumentError, "Missing 'public_key_path' key in secrets.yml for gpg:#{gpg_secrets_key}." if public_key_required && key_data['public_key_path'].blank?

    key_data
  end
  private_class_method :get_key_data

  def self.possibly_make_tempfile possible_io, possible_tempfile_name
    temp = false
    io = nil


    # Basically, the only thing we can utilize currently passed from the caller is a File instance
    # of some sort...because the data needs to be written to disk for the GPG binary to be able to
    # decrypt it
    if possible_io.is_a?(Tempfile) || possible_io.is_a?(File)
      io = possible_io
    else
      io = Tempfile.open(possible_tempfile_name)
      io.binmode
      temp = true
    end

    {io: io, temp: temp}
  end
  private_class_method :possibly_make_tempfile

  # This is set in an initailizer (it defaults to gpg1)
  cattr_accessor :gpg_binary

  attr_reader :public_key_path, :private_key_path

  def initialize(public_key_path, private_key_path = nil)
    @public_key_path = public_key_path
    @private_key_path = private_key_path
  end

  def encrypt_file(input_file_path, output_file_path)
    GpgHelper.encrypt_file @public_key_path, get_file_path(input_file_path), get_file_path(output_file_path)
    nil
  end

  def decrypt_file(input_file_path, output_file_path, passphrase = nil)
    GpgHelper.decrypt_file(@public_key_path, @private_key_path, get_file_path(input_file_path), get_file_path(output_file_path), passphrase)
    nil
  end

  private
    def get_file_path file
      if file.respond_to?(:path)
        file.path
      elsif file.respond_to?(:to_path)
        file.to_path
      else
        file.to_s
      end
    end

    # The following class was pretty much lifted straight from the rgpg gem.  That gem has some issues that have been corrected
    # here - since it's not maintained, I copied the code rather than PR'ing a fix.
    #
    # The nice thing about this class is that every invocation of it creates a 1 time use keychain/secret keychain.  You then don't
    # have to worry about the state of your gpg chain at any time, it's always rebuilt every invocation.  Since we don't encrypt/decrypt
    # files THAT often, the extra work is not that big of a deal.
    #
    # It does not allow setting the gpg binary name, nor does it function with gpg V2.  gpg v2.1 has it's own issues,
    # mainly that you can't really pass the password on the commandline to it, because they require user interaction via
    # an gpg-agent.  Hence, we need to make sure on older gpg v1 is available to use instead, at least for now.
    class GpgHelper

      def self.generate_key_pair(key_base_name, recipient, real_name)
          public_key_file_name = "#{key_base_name}.pub"
          private_key_file_name = "#{key_base_name}.sec"
          script = generate_key_script(public_key_file_name, private_key_file_name, recipient, real_name)
          with_temp_home_dir do |home_dir|
            Tempfile.open("gpg-script") do |script_file|
              script_file.write(script)
              script_file.flush

              run_gpg_no_capture(home_dir,
                '--batch',
                '--gen-key', script_file.path
              )
            end
          end
        end

        def self.encrypt_file(public_key_file_name, input_file_name, output_file_name)
          raise ArgumentError.new("Public key file \"#{public_key_file_name}\" does not exist") unless File.exist?(public_key_file_name)
          raise ArgumentError.new("Input file \"#{input_file_name}\" does not exist") unless File.exist?(input_file_name)

          with_temp_home_dir do |home_dir|
            recipient = get_recipient(home_dir, public_key_file_name)
            with_temporary_encrypt_keyring(home_dir, public_key_file_name) do |keyring_file_name|
              run_gpg_capture(home_dir,
                '--keyring', keyring_file_name,
                '--output', output_file_name,
                '--encrypt',
                '--recipient', recipient,
                '--yes',
                '--trust-model', 'always',
                '--no-tty',
                '--batch',
                input_file_name
              )
            end
          end
        end

        def self.decrypt_file(public_key_file_name, private_key_file_name, input_file_name, output_file_name, passphrase=nil)
         raise ArgumentError.new("Private key file \"#{private_key_file_name}\" does not exist") unless File.exist?(private_key_file_name)
          raise ArgumentError.new("Input file \"#{input_file_name}\" does not exist") unless File.exist?(input_file_name)


          with_temp_home_dir do |home_dir|
            recipient = get_recipient(home_dir, private_key_file_name)
            with_temporary_decrypt_keyrings(home_dir, private_key_file_name, passphrase) do |keyring_file_name, secret_keyring_file_name|
              args = ['--keyring', keyring_file_name,
                     '--secret-keyring', secret_keyring_file_name,
                     '--decrypt',
                     '--batch',
                     '--yes',
                     '--trust-model', 'always',
                     '--no-tty']
              if passphrase
                args.push *["--passphrase", passphrase]
              end

              args.push *['--output', output_file_name, input_file_name]
              run_gpg_capture(home_dir, *args)
            end
          end
        end

        private

        def self.with_temp_home_dir
          Dir.mktmpdir('.rgpg-tmp-') do |home_dir|
            yield home_dir
          end
        end

        def self.build_safe_command_line(home_dir, *args)
          gpg = GPG.gpg_binary
          # Verify the gpg binary points to something valid.
          raise "GPG binary path must point to a gpg executable." unless Pathname.new(gpg).basename.to_s =~ /\Agpg/i
          fragments = [
            gpg,
            '--homedir', home_dir,
            '--no-default-keyring'
          ] + args
          fragments.collect { |fragment| Shellwords.escape(fragment) }.join(' ')
        end

        def self.run_gpg_no_capture(home_dir, *args)
          command_line = build_safe_command_line(home_dir, *args)
          result = system(command_line)
          raise RuntimeError.new('gpg failed') unless result
        end

        def self.run_gpg_capture(home_dir, *args)
          output = nil
          Tempfile.open('gpg-output') do |output_file|
            command_line = build_safe_command_line(home_dir, *args)

            result = system("#{command_line} > #{Shellwords.escape(output_file.path)} 2>&1")

            # The easiest way to retrieve data written to a file outside of ruby is just to
            # open another file descriptor
            output = IO.read(output_file.path)
            raise RuntimeError.new("gpg failed: #{output}") unless result
          end

          output.nil? ? nil : output.lines.collect(&:chomp)
        end

        def self.generate_key_script(public_key_file_name, private_key_file_name, recipient, real_name)
          <<-EOS
      %echo Generating a standard key
      Key-Type: DSA
      Key-Length: 1024
      Subkey-Type: ELG-E
      Subkey-Length: 1024
      Name-Real: #{real_name}
      Name-Comment: Key automatically generated by rgpg
      Name-Email: #{recipient}
      Expire-Date: 0
      %pubring #{public_key_file_name}
      %secring #{private_key_file_name}
      # Do a commit here, so that we can later print "done" :-)
      %commit
      %echo done
          EOS
        end

        def self.get_recipient(home_dir, key_file_name)
          lines = run_gpg_capture(home_dir, "--list-packets", "--batch", key_file_name)
          result = lines.detect { |line| line =~ /^:user ID packet:\s+".+<(.+)>"/ }
          raise RuntimeError.new('Invalid output') unless result

          $1
        end

        def self.with_temporary_encrypt_keyring(home_dir, public_key_file_name)
          with_temporary_keyring_file do |keyring_file_name|
            run_gpg_capture(home_dir,
              '--keyring', keyring_file_name,
              '--import', public_key_file_name
            )
            yield keyring_file_name
          end
        end

        def self.with_temporary_decrypt_keyrings(home_dir, private_key_file_name, passphrase)
          with_temporary_keyring_file do |keyring_file_name|
            with_temporary_keyring_file do |secret_keyring_file_name|
              args = []
              if !passphrase.nil?
                args.push *["--batch", "--passphrase", passphrase]
              end

              args.push *[
                '--keyring', keyring_file_name,
                '--secret-keyring', secret_keyring_file_name,
                '--import', private_key_file_name
              ]


              run_gpg_capture(home_dir, *args)
              yield keyring_file_name, secret_keyring_file_name
            end
          end
        end

        def self.with_temporary_keyring_file
          Tempfile.open("gpg-key-ring") do |keyring_file|
            keyring_file_name = keyring_file.path
            begin
              # keyring_file.close
              # keyring_file.unlink
              yield keyring_file_name
            ensure
              # Apparently gpg makes a backup of the keyring file, this should be cleared too.
              backup_keyring_file_name = "#{keyring_file_name}~"
              File.unlink(backup_keyring_file_name) if File.exist?(backup_keyring_file_name)
            end
          end
        end
      end

end; end;