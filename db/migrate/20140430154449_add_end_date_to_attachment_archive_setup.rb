class AddEndDateToAttachmentArchiveSetup < ActiveRecord::Migration
  def change
    add_column :attachment_archive_setups, :end_date, :date
  end
end
