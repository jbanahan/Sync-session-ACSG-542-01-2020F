class UpdateEntryBrokerId < ActiveRecord::Migration
  def up
    if MasterSetup.get.custom_feature?("Kewill Entries")
      add_vandegrift_update_entries
    end

    if MasterSetup.get.custom_feature?("fenix")
      add_als_update_entries
    end

    if MasterSetup.get.custom_feature?("Kewill Entries") || MasterSetup.get.custom_feature?("Maersk Cargowise Feeds")
      add_damco_update_entries
    end
  end

  def add_vandegrift_update_entries
    vandegrift = add_vandegrift_broker
    update_broker_entries(us, "316", vandegrift)
  end

  def add_als_update_entries
    als = add_als_broker
    update_broker_entries(ca, "11981", als)
  end

  def add_damco_update_entries
    damco = add_damco_broker
    update_broker_entries(us, "595", damco)
    update_broker_entries(ca, "12161", damco)
  end

  def add_vandegrift_broker
    c = nil
    if MasterSetup.get.custom_feature?("WWW")
      # For WWW we want to associate the 316 account with the master account
      c = Company.where(master: true).first
    else
      c = Company.brokers.where("name like ?", "%Vandegrift%").first
      if c.nil?
        c = Company.create!(broker: true, name: "Vandegrift Forwarding Inc.")
      end
    end

    add_filer_code(c, "316")
    c
  end

  def add_damco_broker
    c = Company.brokers.where("name like ?", "%DAMCO%").first
    if c.nil?
      c = Company.create! broker: true, name: "DAMCO Customs Services Inc."
    end
    add_filer_code(c, "595")
    add_filer_code(c, "12161")
    c
  end

  def add_als_broker
    c = Company.brokers.where("name like ?", "%ALS CUSTOMS SERVICE%").first
    if c.nil?
      c = Company.create! broker: true, name: "ALS Customs Services Inc."
    end
    add_filer_code(c, "11981")
    c
  end

  def add_filer_code company, filer_code
    if !has_filer_code?(company, filer_code)
      company.system_identifiers.create! system: "Filer Code", code: filer_code
    end
  end

  def has_filer_code? company, filer_code # rubocop:disable Naming/PredicateName
    company.system_identifiers.any? {|s| s.system == "Filer Code" && s.code == filer_code }
  end

  def update_broker_entries import_country, filer_code, broker
    Entry.where(broker_id: nil, import_country_id: import_country.id).where("entry_number LIKE ?", "#{filer_code}%").update_all(broker_id: broker.id) # rubocop:disable Rails/SkipsModelValidations
  end

  def us
    @us ||= Country.where(iso_code: "US").first
  end

  def ca
    @ca ||= Country.where(iso_code: "CA").first
  end

  def down
    # We don't really have to do anything here...
  end
end
