class CreateAttachmentArchiveManifests < ActiveRecord::Migration
  def change
    create_table :attachment_archive_manifests do |t|
      t.datetime :start_at
      t.datetime :finish_at
      t.integer :company_id

      t.timestamps
    end
    add_index :attachment_archive_manifests, :company_id
  end
end
