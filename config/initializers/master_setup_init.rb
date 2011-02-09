begin
  m = MasterSetup.first
  if m.nil?
    m = MasterSetup.create!(:uuid => UUIDTools::UUID.timestamp_create.to_s)
  end
rescue
  # Intentionally failing silently here.  There are three cases where we will
  # hit an exception here:
  # 1) Error connecting to the database: Something else will quickly fail louder
  # 2) The master_setups table doesn't exist and we're starting up the server:
  #    In this case, we'll throw a loud exception on the first page that tries to load
  # 3) The master_setups table doesn't exist because it's a new database and we're running
  #    rake db:migrate, in which case we don't want this to run yet because we're in the 
  #    process of creating the database tables.
end
