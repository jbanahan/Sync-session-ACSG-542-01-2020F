class CreateHtsTranslations < ActiveRecord::Migration
  def up
    create_table :hts_translations do |t|
      t.references :company
      t.references :country
      t.string :hts_number
      t.string :translated_hts_number
      t.timestamps
    end

    add_index :hts_translations, [:hts_number, :country_id, :company_id], :name => "index_hts_translations_on_hts_and_country_id_and_company_id"
  end

  def down 
    drop_table :hts_translations
  end
end
