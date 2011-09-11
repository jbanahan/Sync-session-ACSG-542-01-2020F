require 'test_helper'

class CacheWrapperTest < ActiveSupport::TestCase

  test "ring error retry - fail once" do
    mt = TestExtensions::MockCache.new
    mt.stubs(:get).raises(Dalli::RingError).then.returns('x')
    mt.expects(:reset)
    cw = CacheWrapper.new(mt)
    assert_equal 'x', cw.get('something')
  end

  test "ring error retry - fail twice" do
    mt = TestExtensions::MockCache.new
    mt.stubs(:get).raises(Dalli::RingError).then.raises(Dalli::RingError).then.returns('x')
    mt.expects(:reset)
    cw = CacheWrapper.new(mt)
    assert_nil cw.get('something')
    assert_equal 'x', cw.get('something')
  end

  test "read yaml file" do
    # Read memcached.yml and confirm you have valid server configs
    yml_file = Tempfile.new('readymltest')
    
    yml_file << "test:\n"
    yml_file << "  server: abc\n"
    yml_file << "  port: 999\n"
    
    yml_file.flush
    client = CacheWrapper.get_production_client(yml_file.path)
    def client.get_server
      @servers
    end
    assert client.get_server.include?("abc:999")
  end
  
  test "read default failovers" do
    # Try to read from an invalid file handle
    client = CacheWrapper.get_production_client("idonotexist.yml")
    # Confirm memcached configs are the defaults
    def client.get_server
      @servers
    end
    assert client.get_server.include?("localhost:11211")
  end
end
