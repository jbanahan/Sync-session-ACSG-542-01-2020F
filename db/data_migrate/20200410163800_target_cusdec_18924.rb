class TargetCusdec18924 < ActiveRecord::Migration
  def up
    return unless MasterSetup.get.custom_feature?("Target")

    usa = Country.where(iso_code: "US").first

    c = Company.where(name: "Vandegrift Forwarding Co.", broker: true).first_or_create!
    c.addresses.where(system_code: "10", name: "Vandegrift Forwarding Co., Inc.", line_1: "20 South Charles Street", line_2: "STE 501", city: "Baltimore", state: "MD", postal_code: "21201", country_id: usa&.id).first_or_create!
    c.addresses.where(system_code: "4", name: "Vandegrift Forwarding Co., Inc.", line_1: "180 E Ocean Blvd", line_2: "Suite 270", city: "Long Beach", state: "CA", postal_code: "90802", country_id: usa&.id).first_or_create!
    c.system_identifiers.where(system: "Filer Code", code: "316").first_or_create!
  end

  def down
    # No need to delete the company record.  It might have already been created under some
    # other project as well.
  end
end