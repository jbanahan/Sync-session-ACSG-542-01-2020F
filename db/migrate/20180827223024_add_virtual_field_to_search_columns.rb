class AddVirtualFieldToSearchColumns < ActiveRecord::Migration
  def up
    change_table(:search_columns, bulk: true) do |t|
      t.column :constant_field_name, :string
      t.column :constant_field_value, :string
    end

    sql = <<-SQL
      UPDATE search_columns 
      SET model_field_uid = '_const', constant_field_name = '[blank]', constant_field_value = '' 
      WHERE model_field_uid = '_blank' AND search_setup_id IS NOT NULL
    SQL
    
    execute sql
  end

  def down
    change_table(:search_columns, bulk: true) do |t|
      t.remove :constant_field_name
      t.remove :constant_field_value
    end

    execute "UPDATE search_columns SET model_field_uid = '_blank' WHERE model_field_uid LIKE '%_const%'"
  end
end
