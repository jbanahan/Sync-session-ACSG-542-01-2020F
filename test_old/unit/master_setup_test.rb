require 'test_helper'

class MasterSetupTest < ActiveSupport::TestCase
  test "version" do
    v = Rails.root.join("config","version.txt").read
    assert MasterSetup.current_code_version==v, "Version should match content of version.txt"
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

  test "need upgrade" do
    current_version = MasterSetup.current_code_version

    #if target_version isn't set, return false
    MasterSetup.get.update_attributes :target_version=>nil
    assert !MasterSetup.need_upgrade?

    #make sure current_version is the same as target_version
    MasterSetup.get.update_attributes :target_version=>current_version
    assert !MasterSetup.need_upgrade?

    #if target version != current version, then return true
    MasterSetup.get.update_attributes :target_version=>"somethingelse"
    assert MasterSetup.need_upgrade?
  end
end
