require 'test_helper'

class MasterSetupTest < ActiveSupport::TestCase
  test "version" do
    v = Rails.root.join("config","version.txt").read
    assert MasterSetup.first.version==v, "Version should match content of version.txt"
  end

  test "migration lock local host" do
    h = `hostname`.strip
    MasterSetup.get_migration_lock
    assert_equal h, MasterSetup.get.migration_host
  end

  test "migration lock" do
    a_host = "hosta"
    b_host = "hostb"

    #grab the lock
    assert MasterSetup.get_migration_lock(a_host)
    #confirm the lock is written
    assert_equal a_host, MasterSetup.get.migration_host
    #a_host should return true again since it already has the lock
    assert MasterSetup.get_migration_lock(a_host)
    
    #fail grabbing the lock
    assert !MasterSetup.get_migration_lock(b_host)

    #clear the lock
    MasterSetup.release_migration_lock
    assert_nil MasterSetup.get.migration_host

    #grab the lock for b
    assert MasterSetup.get_migration_lock(b_host)
    #a can't take the lock
    assert !MasterSetup.get_migration_lock(a_host)
    MasterSetup.release_migration_lock
  end
end
