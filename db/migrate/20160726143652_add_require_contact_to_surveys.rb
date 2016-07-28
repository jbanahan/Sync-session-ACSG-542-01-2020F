class AddRequireContactToSurveys < ActiveRecord::Migration
  def self.up
    add_column :surveys, :require_contact, :boolean
    execute "UPDATE surveys SET require_contact = true WHERE require_contact IS NULL;"
  end

  def self.down
    remove_column :surveys, :require_contact
  end
end
