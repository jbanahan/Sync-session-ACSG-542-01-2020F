module ConfigMigrations; module Www; class EntryPurgeGroupSow1850
  def up
    make_group
  end

  def down
    remove_group
  end

  def make_group
    group = Group.use_system_group "Entry Purge", name:"Entry Purge", description:"Users able to purge entries."

    # Add all sys admin users to the new purge group.  Previously, sys admins were the only people allowed to purge.
    sys_admins = User.where(sys_admin:true)
    sys_admins.each do |user|
      user.groups << group
      user.save!
    end
  end

  def remove_group
    Group.where(system_code:'Entry Purge').destroy_all
  end
end; end; end
