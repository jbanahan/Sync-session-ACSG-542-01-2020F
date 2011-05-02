require 'test_helper'

class CachManagerTest < ActiveSupport::TestCase

  test "namespace" do
    u = MasterSetup.first.uuid
    assert CacheManager.namespace==u
    Rails.expects(:env).returns("production")
    FileUtils.touch 'tmp/restart.txt'
    ns = CacheManager.namespace
    assert ns.length==u.length+10
    assert (ns[0,10].to_i-Time.now.to_i).abs < 100 #should be a time prefix and within 100ms of now
    found = ns[10,ns.length-10] 
    assert found==u, "Expected #{u}, got #{found}, full namespace #{ns}"
  end

end
