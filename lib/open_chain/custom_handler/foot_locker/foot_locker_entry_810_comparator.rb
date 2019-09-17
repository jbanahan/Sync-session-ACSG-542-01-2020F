require 'open_chain/ftp_file_support'
require 'open_chain/custom_handler/vandegrift/kewill_entry_comparator'
require 'open_chain/custom_handler/foot_locker/foot_locker_810_generator'

module OpenChain; module CustomHandler; module FootLocker; class FootLockerEntry810Comparator
  extend OpenChain::EntityCompare::EntryComparator
  include OpenChain::FtpFileSupport
  include OpenChain::XmlBuilder

  def self.accept? snapshot
    accept = super
    if accept
      entry = snapshot.recordable
      customer_enabled = ['FOOLO', 'FOOCA', 'TEAED'].include?(entry.customer_number) || is_foot_locker_canada?(entry.customer_number)
      accept = (customer_enabled) && has_all_entry_dates?(entry) && recent_entry?(entry) && entry.broker_invoices.length > 0
    end

    accept
  end

  def self.has_all_entry_dates? entry
    # Arrival date for newer Canada entries received via Fenix is populated with the release date.
    # It is blank, however, in older entries.  Since it's just a dupe of release date anyway, there's no point
    # in checking for it.
    required_date_fields = is_foot_locker_canada?(entry.customer_number) ? [:entry_filed_date, :file_logged_date, :release_date] :
                                [:entry_filed_date, :file_logged_date, :arrival_date, :release_date]

    required_date_fields.each do |attribute|
      val = entry.public_send(attribute)
      return false if val.nil?
    end

    return true
  end

  # 810s are not generated for older entries.  There's an arbitrary cut-off point.  File logged date was chosen
  # because it's set for Kewill and Fenix-sourced entries.
  def self.recent_entry? entry
    entry.file_logged_date >= Date.new(2019, 1, 1)
  end

  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    entry = Entry.where(id: id).first

    return unless entry

    Lock.db_lock(entry) do 
      invoices_to_send = []
      entry.broker_invoices.each do |invoice|
        # Create the sync records here, so that below when ftping them we know they'll always be present
        sr = invoice.sync_records.find {|sr| sr.trading_partner == "FOOLO 810"}
        invoices_to_send << invoice if sr.try(:sent_at).nil?
      end

      self.new.generate_and_send(entry) if invoices_to_send.length > 0 
    end
  end

  def generate_and_send entry
    entry.broker_invoices.each do |invoice|
      xml = xml_generator.generate_xml invoice
      sr = invoice.sync_records.find {|sr| sr.trading_partner == "FOOLO 810"}

      if sr.nil?
        sr = invoice.sync_records.build trading_partner: "FOOLO 810"
      end

      # XML might be blank if the invoices have no charges that should be transmitted
      if !xml.blank?
        Tempfile.open(["Foolo810-#{invoice.invoice_number.strip}-",'.xml']) do |t|
          write_xml(xml, t)
          t.flush
          t.rewind
          suffix = self.class.is_foot_locker_canada?(entry.customer_number) ? '_CA' : ''
          ftp_sync_file t, sr, connect_vfitrack_net("to_ecs/footlocker_810#{suffix}")
        end
      end

      # Even if the xml was blank, we'll still want to set a sync record so we know the invoice was processed
      sr.sent_at = Time.zone.now
      sr.confirmed_at = (Time.zone.now + 1.minute)
      sr.save!
    end
  end

  def xml_generator
    OpenChain::CustomHandler::FootLocker::FootLocker810Generator.new
  end

  def self.is_foot_locker_canada? customer_number
    ['FOOTLOCKE', 'FOOT LOCKER CANADA C'].include?(customer_number)
  end

end; end; end; end