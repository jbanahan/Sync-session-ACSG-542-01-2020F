class AddFdaDatesToEntry < ActiveRecord::Migration
  def self.up
    add_column :entries, :fda_release_date, :datetime
    add_column :entries, :fda_review_date, :datetime
    add_column :entries, :fda_transmit_date, :datetime
    add_column :entries, :release_cert_message, :string
    add_column :entries, :fda_message, :string
  end

  def self.down
    remove_column :entries, :release_cert_message
    remove_column :entries, :fda_message
    remove_column :entries, :fda_transmit_date
    remove_column :entries, :fda_review_date
    remove_column :entries, :fda_release_date
  end
end
