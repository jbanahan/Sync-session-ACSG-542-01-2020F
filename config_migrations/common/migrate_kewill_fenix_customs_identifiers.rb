module ConfigMigrations; module Common; class MigrateKewillFenixCustomsIdentifiers

  def up
    Company.where("alliance_customer_number IS NOT NULL OR fenix_customer_number IS NOT NULL").find_each do |c|
      if !c.alliance_customer_number.blank? && c.kewill_customer_number.blank?
        c.system_identifiers.create! system: "Customs Management", code: c.alliance_customer_number
      end

      if !c.fenix_customer_number.blank? && c.fenix_customer_identifier.blank?
        c.system_identifiers.create! system: "Fenix", code: c.fenix_customer_number
      end
    end
  end

end; end; end;