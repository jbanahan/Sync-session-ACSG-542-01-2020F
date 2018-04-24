class AddSuppressEmailSuppressFtpToMasterSetups < ActiveRecord::Migration
  def change
    add_column :master_setups, :suppress_email, :boolean
    add_column :master_setups, :suppress_ftp, :boolean
  end
end
