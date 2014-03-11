class CreateStitchQueue < ActiveRecord::Migration
  def change
    create_table :stitch_queue_items do |t|
      t.string :stitch_type
      t.string :stitch_queuable_type
      t.integer :stitch_queuable_id

      t.timestamps
    end

    add_index :stitch_queue_items, [:stitch_type, :stitch_queuable_type, :stitch_queuable_id], :unique => true, :name=>"index_stitch_queue_item_by_types_and_id"
  end

end
