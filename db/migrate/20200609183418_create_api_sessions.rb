class CreateApiSessions < ActiveRecord::Migration
  def change
    create_table :api_sessions do |t|
      t.string :endpoint
      t.string :class_name
      t.string :last_server_response
      t.string :request_file_name
      t.integer :retry_count

      t.timestamps null: false
    end
  end
end
