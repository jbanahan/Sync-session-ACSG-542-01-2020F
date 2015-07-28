class AlterOfficialTariffsSpecialRatesToText < ActiveRecord::Migration
  def up
    change_column(:official_tariffs, :special_rates, :text)
  end

  def down
    # Do nothing on rollback, there's nothing from an application standpoint that needs this column as a varchar vs. text column.
    # All we'd be doing is forcing a ton of backend DB work to happen versus a no-op.
  end
end
