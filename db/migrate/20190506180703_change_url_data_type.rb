class ChangeUrlDataType < ActiveRecord::Migration
  def change
    reversible do |direction|
      change_table(:request_logs, bulk: true) do |t|
        direction.up { migrate_up(t) }
        direction.down { migrate_down(t) }
      end
    end
  end

  def migrate_up t
    t.change :url, :text
  end

  def migrate_down t
    t.change :url, :string
  end
end
