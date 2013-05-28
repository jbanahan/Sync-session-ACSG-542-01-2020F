class CreateExportJobs < ActiveRecord::Migration
  def up
    create_table :export_jobs do |t|
      t.timestamp :start_time
      t.timestamp :end_time
      t.boolean :successful
      t.string :export_type
      t.timestamps
    end

    create_table :export_job_links do |t|
      t.references :export_job, :null => false
      t.references :exportable, :polymorphic => true, :null => false
    end

    add_index :export_job_links, [:exportable_id, :exportable_type]
    add_index :export_job_links, [:export_job_id]
  end

  def down 
    drop_table :export_job_links
    drop_table :export_jobs
  end
end
