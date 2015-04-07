if Rails.env.production? && ActiveRecord::Base.connection.table_exists?('instance_informations')
  MasterSetup.get
  InstanceInformation.check_in
end
