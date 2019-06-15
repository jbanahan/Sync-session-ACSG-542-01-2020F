class CreateConstantTexts < ActiveRecord::Migration
  def up
    create_table(:constant_texts) do |t|
      t.string :text_type, null: false
      t.string :constant_text, null: false
      t.date :effective_date_start, null: false
      t.date :effective_date_end
      t.integer :constant_textable_id, null: false
      t.string :constant_textable_type, null: false

      t.timestamps null: false
    end

    add_index :constant_texts, [:constant_textable_id, :constant_textable_type], name: "idx_constant_textable_id_and_constant_textable_type"
  end

  def down
    drop_table :constant_texts
  end
end
