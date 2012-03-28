class ResentEntryAttachmentPermission < ActiveRecord::Migration
  def self.up
    execute "UPDATE users SET entry_attach = 0;"
  end

  def self.down
  end
end
