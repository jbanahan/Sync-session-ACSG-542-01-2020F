class AlterLockNameColumnSize < ActiveRecord::Migration
  def up
    change_column(:locks, :name, :string, limit: 255)
  end

  def down
  end
end
