require 'test_helper'

class CacheWrapperTest < ActiveSupport::TestCase
  test "read yaml file" do
    # Read memcached.yml and confirm you have valid server configs
    yml_file = Tempfile.new('readymltest')
    #yml_file << "%{"
    yml_file << "test:\n"
    yml_file << "server: abc"
    yml_file << "port: 999"
    
    yml_file.flush
    client = CacheWrapper.get_production_client(yml_file.path)
    def client.get_server
      @servers
    end
    assert_equal "abc:999", client.get_server
  end
  
  test "read default failovers" do
    # Try to read from an invalid file handle
    client = CacheWrapper.get_production_client("/config/memcarched.yml")
    # Confirm memcached configs are the defaults
    
  end
end