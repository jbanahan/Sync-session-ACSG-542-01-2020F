class AddTariffSubscribedToUser < ActiveRecord::Migration
  def change
    add_column :users, :tariff_subscribed, :boolean
  end
end
