class CreateDataCrossReferences < ActiveRecord::Migration
  def change
    create_table :data_cross_references do |t|
      t.string :key
      t.string :value
      t.string :cross_reference_type
      t.integer :company_id
      t.timestamps
    end

    add_index :data_cross_references, [:key, :cross_reference_type, :company_id], {:unique => true, :name => 'index_data_xref_on_key_and_xref_type_and_company_id'} 
  end
end
