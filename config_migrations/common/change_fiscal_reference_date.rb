require 'open_chain/fiscal_month_assigner'

module ConfigMigrations; module Common; class ChangeFiscalReferenceDate

  def up source_system, customer_number, file_logged_date_start, fiscal_reference_date
    user = User.integration

    company = nil
    if source_system == "Alliance"
      company = Company.importers.where(alliance_customer_number: customer_number).first
      raise "Failed to find Kewill Customer Number '#{customer_number}'." if company.nil?
    else
      company = Company.importers.where(fenix_customer_number: customer_number).first
      raise "Failed to find Fenix Customer Number '#{customer_number}'." if company.nil?
    end

    model_field = ModelField.find_by_uid fiscal_reference_date
    raise "Invalid Fiscal Reference Date '#{fiscal_reference_date}'." if model_field.blank?
    raise "Fiscal Reference field '#{model_field.label}' is not an Entry field." if model_field.core_module.class_name != "Entry"

    company.update_attributes! fiscal_reference: fiscal_reference_date

    find_entries(company, file_logged_date_start).find_each do |entry|
      Lock.with_lock_retry(entry) do 
        OpenChain::FiscalMonthAssigner.assign entry

        if changed? entry
          entry.save!
          entry.create_snapshot user, nil, "Fiscal Reference Update: #{model_field.label}"
        end
      end
    end
  end


  def find_entries importer, file_logged_date_start
    Entry.where(importer_id: importer.id).where("file_logged_date > ?", file_logged_date_start)
  end

  def changed? entry
    return true if entry.changed?

    entry.broker_invoices.each do |inv|
      return true if inv.changed?
    end

    return false
  end

end; end; end;