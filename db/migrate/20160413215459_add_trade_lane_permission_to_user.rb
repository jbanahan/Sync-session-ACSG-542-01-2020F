class AddTradeLanePermissionToUser < ActiveRecord::Migration
  def change
    add_column :users, :User, :string
    add_column :users, :trade_lane_view, :boolean
    add_column :users, :trade_lane_edit, :boolean
    add_column :users, :trade_lane_attach, :boolean
    add_column :users, :trade_lane_comment, :boolean
  end
end
