class BillingInvoiceGenerator1982 < ActiveRecord::Migration
  def up
    return unless MasterSetup.get.custom_feature?("WWW")

    # Create a remit to address for Vandegrift.
    vandegrift = Company.with_identifier("Filer Code", "316").first
    us = Country.where(iso_code: "US").first
    if vandegrift && us
      Address.where(company: vandegrift, name: "Vandegrift, Inc.", line_1: "180 Park Avenue", city: "Florham Park",
                    state: "NJ", postal_code: "07932", country: us, address_type: "Remit To",
                    system_code: "Remit To").first_or_create!
    end

    # Billing Invoice cross ref.  So far, Emser's the only member.
    DataCrossReference.where(cross_reference_type: "billing_invoice_customer", key: "EMSER").first_or_create!
  end

  def down
    # No need to purge the address record or cross ref created in 'up'.
  end
end