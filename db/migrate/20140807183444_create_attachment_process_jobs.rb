class CreateAttachmentProcessJobs < ActiveRecord::Migration
  def change
    create_table :attachment_process_jobs do |t|
      t.references :attachment
      t.string :job_name
      t.datetime :start_at
      t.datetime :finish_at
      t.string :error_message
      t.references :user
      t.references :attachable, polymorphic: true

      t.timestamps
    end
    add_index :attachment_process_jobs, :attachment_id
    add_index :attachment_process_jobs, :user_id
    add_index :attachment_process_jobs, [:attachable_id,:attachable_type], name: 'attachable_idx'
  end
end
