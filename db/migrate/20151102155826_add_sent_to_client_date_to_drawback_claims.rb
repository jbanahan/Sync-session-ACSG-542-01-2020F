class AddSentToClientDateToDrawbackClaims < ActiveRecord::Migration
  def up
    add_column :drawback_claims, :sent_to_client_date, :date
  end

  def down
    remove_column :drawback_claims, :sent_to_client_date
  end
end
