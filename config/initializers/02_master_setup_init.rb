# This is here to ensure that as the instances start they're caching and using
# the most up to date version of the master setup class.  There is potentially still some moments in time
# where one system may be spinning down and the others spinning up where their could be conflicts 
# in what master setup is cached, but ultimately as all the servers come back online (usually within
# split seconds of eachother) as the last server comes online, this call will clear the cache and the correct
# master setup will be always be used.
if !MasterSetup.running_from_console? && MasterSetup.master_setup_initialized?
  ms = MasterSetup.first
  ms.update_cache

  if MasterSetup.production_env? && ActiveRecord::Base.connection.table_exists?('instance_informations')
    InstanceInformation.check_in
  end
end
