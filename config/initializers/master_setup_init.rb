# The check for tables occurs so these initializations don't run during a rake db:migrate
# on an empty database (say from our CI servers).
conn = ActiveRecord::Base.connection
if conn.table_exists? 'master_setups'
  MasterSetup.init_base_setup
end

if conn.table_exists?('companies') && conn.table_exists?('users')
  c = Company.first_or_create!(name:'My Company',master:true) 
  if c.users.empty?
    pass = 'init_pass'
    u = c.users.build(:username=>"chainio_admin",:email=>"support@vandegriftinc.com")
    u.password = pass
    u.sys_admin = true
    u.admin = true
    u.save
    OpenMailer.send_new_system_init(pass).deliver if Rails.env=="production"
  end
end

if Rails.env.production? && ActiveRecord::Base.connection.table_exists?('instance_informations')
  InstanceInformation.check_in
end

