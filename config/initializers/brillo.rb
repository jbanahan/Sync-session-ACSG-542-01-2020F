require 'faker'

Brillo.configure do |config|
  @customer_hash = nil

  if MasterSetup.secrets.aws
    config.transfer_config.secret_access_key = MasterSetup.secrets.aws["secret_access_key"]
    config.transfer_config.access_key_id = MasterSetup.secrets.aws["access_key_id"]
    config.transfer_config.bucket = MasterSetup.secrets.brillo_bucket
  end

  # Tactics define what data is pulled in, and how it is pulled in.
  config.add_tactic :isf_module, -> (klass) { klass.where(broker_customer_number: ["EDDIE", "PVH"]).where(["file_logged_date > ? AND file_logged_date < ?", Date.parse("01/05/2019"), Date.parse("01/07/2019")]) }
  config.add_tactic :broker_invoice_module, -> (klass) { klass.where(customer_number: ["FOOLO"]).where(["invoice_date > ? AND invoice_date < ?", Date.parse("01/05/2018"), Date.parse("01/07/2019")])}
  config.add_tactic :customer_invoice_module, -> (klass) { klass.joins(:importer).where("companies.system_code = 'ATAYLOR'").where(["invoices.invoice_date > ? AND invoices.invoice_date < ?", Date.parse("01/05/2018"), Date.parse("01/07/2019")])}
  config.add_tactic :product_module, -> (klass) { klass.where("unique_identifier REGEXP '^LENOX |^ASCENA |^JILL'") }
  config.add_tactic :order_module, -> (klass) { klass.joins(:importer).where("companies.system_code IN ('JJILL', 'ASCENA')").where(["orders.order_date > ? AND orders.order_date < ?", Date.parse("01/06/2019"), Date.parse("01/07/2019")])}
  config.add_tactic :shipment_module, -> (klass) { klass.joins(:importer).where("companies.system_code IN ('JJILL')").where(["shipments.bol_date > ?", Date.parse("01/04/2019")])}
  config.add_tactic :entry_module, -> (klass) { klass.joins(:importer).where("companies.system_code IN ('JJILL', 'ASCE', 'ADVAN', 'CQSOU', 'CQ', 'MAURICES', 'TWEEN' 'LUMBER', 'FOOLO')").where(["entries.file_logged_date > ? AND entries.file_logged_date < ?", Date.parse("01/06/2017"), Date.parse("01/07/2019")])}

  # Obfuscations...obfuscate
  config.add_obfuscation :empty_out, -> (field) {
    ""
  }

  config.add_obfuscation :customer_name, -> (field) {
    Faker::Company.name
  }

  config.add_obfuscation :company_name, -> (field, instance) {
    if instance.alliance_customer_number.present?
      downcased_alliance = instance.alliance_customer_number.downcase
      customer_hash[downcased_alliance].present? ? customer_hash[downcased_alliance] : Faker::Company.name
    else
      Faker::Company.name
    end
  }

  config.add_obfuscation :entry_customer_name, -> (field, instance) {
    if instance.customer_number.present?
      downcased_number = instance.customer_number.downcase
      customer_hash[downcased_number].present? ? customer_hash[downcased_number] : Faker::Company.name
    else
      Faker::Company.name
    end
  }

  config.add_obfuscation :master_suppression, -> (field, instance) {
    true
  }

  config.add_obfuscation :master_host, -> (field, instance) {
    # This is a total and complete hack.
    #
    # Brillo, or possibly Polo, is ignoring suppress_ftp and suppress_email despite
    # those fields being loaded as obfuscations.
    #
    # Since this is the case, and there is no rhyme or reason, I am forcing the change
    # directly on the instance. The instance is the AR object and any changes live
    # throughout the run.
    #
    # Certainly not ideal but this rather odd behavior is all but impossible to trace down
    # given that other fields of boolean types will trigger their associated obfuscations.
    instance.suppress_ftp = instance.suppress_email = true
    "demo.vfitrack.net"
  }

  config.add_obfuscation :master_uuid, -> (field, instance) {
    "a5d292f3-cd6c-3beb-81d4-a8b24226880d"
  }

  config.add_obfuscation :master_system_code, -> (field, instance) {
    "demo"
  }

  config.add_obfuscation :master_friendly_system_name, -> (field, instance) {
    "Demo VFI Track"
  }

  config.add_obfuscation :master_custom_features, -> (field, instance) {
    field.gsub("Production", "Demo Aging")
  }

  config.add_obfuscation :customer_address, -> (field) {
    Faker::Address.street_address
  }

  config.add_obfuscation :customer_city, -> (field) {
    Faker::Address.city
  }

  config.add_obfuscation :customer_state, -> (field) {
    Faker::Address.state
  }

  config.add_obfuscation :customer_zip, -> (field) {
    Faker::Address.zip_code
  }

  config.add_obfuscation :product_name, -> (field) {
    Faker::Commerce.product_name
  }

  config.add_obfuscation :division_name, -> (field) {
    Faker::Company.industry
  }

  config.add_obfuscation :house_bills, -> (field) {
    split_string_length = field.split(/\r?\n */).length
    if split_string_length <= 0
      ""
    else
      (1..split_string_length).map { |i| "HBILL#{i}" }.join("\r\n")
    end
  }

  config.add_obfuscation :master_bills, -> (field) {
    split_string_length = field.split(/\r?\n */).length
    if split_string_length <= 0
      ""
    else
      (1..split_string_length).map { |i| "MBILL#{i}" }.join("\r\n")
    end
  }

  config.add_obfuscation :manufacturer_names, -> (field) {
    split_string_length = field.split(/\r?\n */).length
    if split_string_length <= 0
      ""
    else
      (1..split_string_length).map { |i| "Manufacturer #{i}" }.join("\r\n")
    end
  }

  config.add_obfuscation :trucker_name, -> (field) {
    Faker::Name.name
  }

  config.add_obfuscation :attachment_name, -> (field) {
    Faker::File.file_name(dir: '', directory_separator: '')
  }

  config.add_obfuscation :po_number_cipher, -> (field) {
    encrypted_pos = field.split(/\r?\n */).map { |po| OpenChain::BrilloHelper.split_field_cipher(po) }
    encrypted_pos.join("\r\n")
  }

  config.add_obfuscation :hyphen_cipher, -> (field) {
    OpenChain::BrilloHelper.split_field_cipher(field)
  }

  config.add_obfuscation :cipher, -> (field) {
    return "" if field.blank?
    encrypted_string = OpenChain::BrilloHelper.ceaser_cipher(field, 5)
    encrypted_string.join.upcase
  }

  def customer_hash
    @customer_hash ||= OpenChain::BrilloHelper.customer_mappings
  end

end

module OpenChain; class BrilloHelper
  def self.customer_mappings
    customers = ['ASCE', 'JILL', 'ADVAN', 'CQSOU', 'LUMBER', 'FOOLO'].map { |elem| elem.downcase }

    customer_hash = {}
    Faker::Config.random = Random.new(42)
    customers.each do |customer|
      new_customer_name = Faker::Company.name
      ciphered_customer_number = OpenChain::BrilloHelper.ceaser_cipher(customer, 5)
      customer_hash[ciphered_customer_number.join] = new_customer_name
    end

    Faker::Config.random = nil
    customer_hash
  end

  def self.split_field_cipher(string)
    split_field = string.split('-')
    if split_field.length > 1
      split_field[0] = ceaser_cipher(split_field[0], 5).join.strip.upcase
      split_field.join('-')
    elsif split_field[0].include?('-')
      ceaser_cipher(field.gsub('-', ''), 5).join
    else
      string
    end
  end

  def self.ceaser_cipher(string, shift=1)
    alphabet   = Array('a'..'z')
    encrypter  = Hash[alphabet.zip(alphabet.rotate(shift))]
    string.downcase.chars.map { |c| encrypter.fetch(c, " ") }
  end
end; end
