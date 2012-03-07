class CreateLinkedCompanies < ActiveRecord::Migration
  def self.up
    create_table :linked_companies, :id=>false do |t|
      t.integer :parent_id
      t.integer :child_id
    end
    add_index :linked_companies, [:parent_id,:child_id], :unique=>true
  end

  def self.down
    drop_table :linked_companies
  end
end
