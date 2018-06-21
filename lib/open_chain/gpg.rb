# This is mostly just a wrapper around a wrapper around the gpg binary.
# This class is primarily here to facilitate ease of testing gpg uses
# and to insulate from any shifting of the GPG implementation we may need to do.
module OpenChain; class GPG

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
          raise ArgumentError.new("Public key file \"#{public_key_file_name}\" does not exist") unless File.exist?(public_key_file_name)
          raise ArgumentError.new("Private key file \"#{private_key_file_name}\" does not exist") unless File.exist?(private_key_file_name)
          raise ArgumentError.new("Input file \"#{input_file_name}\" does not exist") unless File.exist?(input_file_name)

          
          with_temp_home_dir do |home_dir|
            recipient = get_recipient(home_dir, private_key_file_name)
            with_temporary_decrypt_keyrings(home_dir, public_key_file_name, private_key_file_name, passphrase) do |keyring_file_name, secret_keyring_file_name|
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
          fragments = [
            GPG.gpg_binary,
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

            #The easiest way to retrieve data written to a file outside of ruby is just to 
            #open another file descriptor
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

        def self.with_temporary_decrypt_keyrings(home_dir, public_key_file_name, private_key_file_name, passphrase)
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
              #keyring_file.close
              #keyring_file.unlink
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