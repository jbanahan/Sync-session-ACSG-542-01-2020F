class AddBillingFieldsToDrawbackClaim < ActiveRecord::Migration
  def self.up
    add_column :drawback_claims, :bill_amount, :decimal, :precision=>11, :scale=>2
    add_column :drawback_claims, :net_claim_amount, :decimal, :precision=>11, :scale=>2
  end

  def self.down
    remove_column :drawback_claims, :net_claim_amount
    remove_column :drawback_claims, :bill_amount
  end
end
