class AddHmfMpfCheckReceivedDateToDrawbackClaims < ActiveRecord::Migration
  def change
    add_column :drawback_claims, :hmf_mpf_check_received_date, :date
  end
end
