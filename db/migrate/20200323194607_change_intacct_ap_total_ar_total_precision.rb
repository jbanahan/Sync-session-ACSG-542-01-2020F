class ChangeIntacctApTotalArTotalPrecision < ActiveRecord::Migration
  def up
    change_table(:intacct_alliance_exports, bulk: true) do |t|
      t.change :ap_total, :decimal, :precision => 12, :scale => 2
      t.change :ar_total, :decimal, :precision => 12, :scale => 2
    end
  end

  def down
    change_table(:intacct_alliance_exports, bulk: true) do |t|
      t.change :ap_total, :decimal, :precision => 10, :scale => 2
      t.change :ar_total, :decimal, :precision => 10, :scale => 2
    end
  end
end
