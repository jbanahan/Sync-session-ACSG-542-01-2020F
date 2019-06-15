class ChangeColumn2RateDataType < ActiveRecord::Migration
  def change
    reversible do |direction|
      change_table(:tariff_set_records, bulk: true) do |t|
        direction.up { migrate_up(t) }
        direction.down { migrate_down(t) }
      end
    end
  end

  def migrate_up t
    t.change :column_2_rate, :text
  end

  def migrate_down t
    t.change :column_2_rate, :string
  end
end
