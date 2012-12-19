class AddAmazonBucketToSecurityFiling < ActiveRecord::Migration
  def self.up
    add_column :security_filings, :last_file_bucket, :string
    add_column :security_filings, :last_file_path, :string
  end

  def self.down
    remove_column :security_filings, :last_file_path
    remove_column :security_filings, :last_file_bucket
  end
end
