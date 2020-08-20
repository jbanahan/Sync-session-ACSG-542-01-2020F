class Target1820Sow18928 < ActiveRecord::Migration
  def up
    return unless MasterSetup.get.custom_feature?("Target")

    c = Company.with_customs_management_number("TARGEN").first
    ml = MailingList.where(system_code: "Target 820 Report", company: c, name: "Target 820 Report", user: User.integration).first_or_create!
    ml.update!(email_addresses: "vfirecievables@vandgriftinc.com, payments@vandegriftinc.com")
  end

  def down
    # Does nothing.
  end
end