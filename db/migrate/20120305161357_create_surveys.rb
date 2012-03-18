class CreateSurveys < ActiveRecord::Migration
  def self.up
    create_table :surveys do |t|
      t.integer :company_id
      t.integer :created_by_id
      t.string :name
      t.string :email_subject
      t.text :email_body

      t.timestamps
    end
    add_index :surveys, :company_id
  end

  def self.down
    drop_table :surveys
  end
end
