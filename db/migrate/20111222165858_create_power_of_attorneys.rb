class CreatePowerOfAttorneys < ActiveRecord::Migration
  def self.up
    create_table :power_of_attorneys do |t|
      t.integer :company_id
      t.date :start_date
      t.date :expiration_date
      t.integer :uploaded_by
      t.string :attachment_file_name
      t.string :attachment_content_type
      t.integer :attachment_file_size
      t.datetime :attachment_updated_at

      t.timestamps
    end
  end

  def self.down
    drop_table :power_of_attorneys
  end
end
