class CreateRuntimeLogs < ActiveRecord::Migration
  def change
    create_table :runtime_logs do |t|
      t.datetime :start
      t.datetime :end
      t.string :identifier
      t.references :runtime_logable, polymorphic: true, index: {name: 'index_runtime_logs_on_runtime_logable'}

      t.timestamps null: false
    end

    add_index :runtime_logs, :created_at
    add_column :search_schedules, :log_runtime, :boolean, default: false
    add_column :schedulable_jobs, :log_runtime, :boolean, default: false
  end
end
