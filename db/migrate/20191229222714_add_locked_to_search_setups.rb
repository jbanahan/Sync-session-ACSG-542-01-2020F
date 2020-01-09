class AddLockedToSearchSetups < ActiveRecord::Migration
  def self.up
    add_column :search_setups, :locked, :boolean
    execute <<-SQL
      UPDATE search_setups ss
        INNER JOIN users u ON u.id = ss.user_id
      SET ss.locked = true
      WHERE u.username = "integration"
    SQL
  end

  def self.down
    remove_column :search_setups, :locked
  end
end
