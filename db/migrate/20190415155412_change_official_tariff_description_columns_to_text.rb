class ChangeOfficialTariffDescriptionColumnsToText < ActiveRecord::Migration
  def change
    reversible do |direction|
      change_table(:official_tariffs, bulk: true) do |t|
        direction.up { migrate_up(t) }
        direction.down { migrate_down(t) }
      end
    end
  end

  def migrate_up t
    t.change :chapter, :text
    t.change :heading, :text
    t.change :remaining_description, :text
    t.change :sub_heading, :text
    t.change :column_2_rate, :text
  end

  def migrate_down t
    t.change :chapter, :string, limit: 800
    t.change :heading, :string, limit: 800
    t.change :remaining_description, :string, limit: 800
    t.change :sub_heading, :string, limit: 800
    t.change :column_2_rate, :string
  end
end
