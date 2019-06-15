class CreateInboundFiles < ActiveRecord::Migration
  def up
    create_table :inbound_files do |t|
      t.string :file_name
      t.string :receipt_location
      t.string :parser_name
      t.integer :company_id
      t.datetime :process_start_date
      t.datetime :process_end_date
      t.string :process_status
      t.string :isa_number
      t.string :s3_bucket
      t.string :s3_path
      t.integer :requeue_count
      t.datetime :original_process_start_date
      t.timestamps null: false
    end

    add_index :inbound_files, [:s3_bucket, :s3_path]

    create_table :inbound_file_identifiers do |t|
      t.integer :inbound_file_id
      t.string :identifier_type
      t.string :value
      t.string :module_type
      t.integer :module_id
    end

    create_table :inbound_file_messages do |t|
      t.integer :inbound_file_id
      t.string :message_status
      t.text :message
    end
  end

  def down
    drop_table :inbound_file_messages
    drop_table :inbound_file_identifiers
    drop_table :inbound_files
  end
end
