require 'active_support/secure_random'

if ActiveRecord::Base.connection.tables.include?("master_setups")
  MasterSetup.init_base_setup
end

if (["companies","users"] - ActiveRecord::Base.connection.tables).length == 0
  c = Company.where(:master=>true).first
  c = Company.create(:name=>"My Company",:master=>true) if c.nil?
  u = User.where(:company_id=>c).where(:username=>"chainio_admin").first
  if u.nil?
    pass = ActiveSupport::SecureRandom.base64(6)
    u = c.users.create(:username=>"chainio_admin",:password=>pass,:password_confirmation=>pass,:email=>"chainio@aspect9.com",:admin=>true,:sys_admin=>true)
    OpenMailer.send_new_system_init(pass).deliver
  end
end
