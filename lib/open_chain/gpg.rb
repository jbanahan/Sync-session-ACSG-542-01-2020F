require 'rgpg'

# This is mostly just a wrapper around a wrapper around the gpg binary.
# This class is primarily here to facilitate ease of testing gpg uses
# and to insulate from any shifting of the GPG implementation we may need to do.
module OpenChain; class GPG

  attr_reader :public_key_path, :private_key_path

  def initialize(public_key_path, private_key_path = nil)
    @public_key_path = public_key_path
    @private_key_path = private_key_path
  end

  def encrypt_file(input_file_path, output_file_path)
    Rgpg::GpgHelper.encrypt_file @public_key_path, get_file_path(input_file_path), get_file_path(output_file_path)
    nil
  end

  def decrypt_file(input_file_path, output_file_path, passphrase = nil)
    Rgpg::GpgHelper.decrypt_file(@public_key_path, @private_key_path, get_file_path(input_file_path), get_file_path(output_file_path), passphrase)
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

end; end;