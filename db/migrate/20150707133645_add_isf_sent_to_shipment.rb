class AddIsfSentToShipment < ActiveRecord::Migration
  def change
    add_column :shipments, :isf_sent_at, :datetime
    add_column :shipments, :isf_sent_by_id, :integer
  end
end
