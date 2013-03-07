class AddHmfMpfCheckNumberAndAmountToDrawbackClaims < ActiveRecord::Migration
  def change
    add_column :drawback_claims, :hmf_mpf_check_number, :string
    add_column :drawback_claims, :hmf_mpf_check_amount, :decimal, :precision => 9, :scale => 2
  end
end
