class TargetEntryZip1981 < ActiveRecord::Migration
  def up
    return unless MasterSetup.get.custom_feature?("Target")

    target = Company.with_customs_management_number("TARGEN").first
    return unless target

    ml = MailingList.where(company_id: target.id, system_code: "target_pdf_errors", name: "Target PDF Errors", user: User.integration).first_or_create!
    ml.update! email_addresses: (MasterSetup.get.production? ? "targetdocs@vandegriftinc.com" : "mcarvin@vandegriftinc.com")
  end

  def down
    # Does nothing.
  end
end