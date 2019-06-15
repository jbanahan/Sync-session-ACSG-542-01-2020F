class CreateFiscalMonths < ActiveRecord::Migration
  def self.up
    create_table :fiscal_months do |t|
      t.integer :year
      t.integer :month_number
      t.date :start_date
      t.date :end_date
      t.integer :company_id

      t.timestamps null: false
    end

    add_index :fiscal_months, [:start_date, :end_date]
  end

  def self.down
    drop_table :fiscal_months
  end
end
