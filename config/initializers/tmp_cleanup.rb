if Rails.env.production?
  # There's some weirdness in the way our upgrades happen from time to time, where another upgrade kicks off before the server
  # restarts.
  #
  # What happens then is that since the new one is killed by the passenger restart, it leaves around the in progress file, so that
  # unless we manually log into the server and delete the file, the next time we try and do an upgrade from the master setups page, the system
  # will think it's still upgdating and won't do the new update.
  #
  # We're going to delete the upgrade file on every restart, since we're assuming a restart implies the upgrade completed.
  upgrade_running = Rails.root.join(OpenChain::Upgrade.upgrade_file_path)
  begin
    upgrade_running.delete if upgrade_running.file?
  rescue Exception => e
    e.log_me
  end
end