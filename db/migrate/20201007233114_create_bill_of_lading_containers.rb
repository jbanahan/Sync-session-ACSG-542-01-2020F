class CreateBillOfLadingContainers < ActiveRecord::Migration
  def change
    create_table :bill_of_lading_containers do |t|
      t.references :bill_of_lading
      t.references :container

      t.timestamps null: false
    end
  end
end
