require 'open_chain/gpg'

# Include this module if the data for the parser implementation may be encrypted with a pgp public key.
#
# If the filename present in the opts variable (opts[:key]) given to the parser's `parse` method has a .pgp
# extension, this module will assume it needs to be decrypted. Otherwise, if there is an opts[:encrypted] key
# present in the ops variable, it will also attempt to decrypt the data.
#
# In order to do the decryptions you can provide the private key path as part of the opts variable to parse
# or you can implement a gpg_parameters method that returns a hash with a `private_key` key containing the path
# to the private can and an optional `passphrase` key (if needed)

module OpenChain; module GpgIntegrationClientParserSupport
  extend ActiveSupport::Concern

  module ClassMethods
    def pre_process_data data, opts
      if opts[:encrypted] == true || File.extname(opts[:key].to_s).upcase == ".PGP"
        secrets_gpg_key = discover_gpg_key(opts)
        return decrypt data, secrets_gpg_key
      else
        return data
      end
    end

    # Actually decrypt the data sent
    def decrypt data, secrets_gpg_key
      # Virtually every single parser at this point receives its data as a String
      # therefore we need to create IO "buffers" so that our GPG method can
      # read that data from the String as an IO like object
      input = nil

      # If our data is already an IO object, then we can just use it as is
      if data.is_a?(StringIO)  || data.class < IO
        input = data
      else
        input = StringIO.new(data)
      end

      output = StringIO.new

      OpenChain::GPG.decrypt_io input, output, secrets_gpg_key

      output.rewind
      output.read
    end

    def discover_gpg_key opts
      # If the private key path comes from the opts, then utilize opts as the data source for the decryption information...otherwise, expect
      # the parser to provide it directly.
      opts[:gpg_secrets_key].presence || gpg_secrets_key(opts)
    end

    # Implement this method to return the key value to use to locate the gpg secrets configuration.
    # A valid set up would look like this. public_key_path is only needed for encryption (not decryption).
    # Passphrase is required only if the private key is protected with a passphrase (in general it should be).
    #
    #  gpg:
    #    some_key:
    #      private_key_path: config/some_key.asc
    #      passphrase: jklasdfj1u9012jay8123l
    # 

    def gpg_secrets_key opts
      raise "You must implement this method and return the key value to use to find the gpg configuration under the secret's gpg key."
    end
  end

end; end;