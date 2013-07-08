class CreateResultCaches < ActiveRecord::Migration
  def change
    create_table :result_caches do |t|
      t.integer :result_cacheable_id
      t.string :result_cacheable_type
      t.integer :page
      t.integer :per_page
      t.text :object_ids

      t.timestamps
    end
    add_index :result_caches, [:result_cacheable_id,:result_cacheable_type], :name=>"result_cacheable"
  end
end
