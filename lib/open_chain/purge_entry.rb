require 'open_chain/s3'

module OpenChain; class PurgeEntry
  def self.run_schedulable
    # We can safely remove entries with a release date or import date older than 8 years for everyone
    # Any customer which does not participate in drawback only gets 5 years from release date or 5.5 years past
    #  import if release date is missing
    all_entry_ids = Entry.joins(:importer)
                         .where("(release_date < ? OR (release_date IS NULL AND import_date < ?))", 8.years.ago, 8.years.ago).ids
    non_drawback_ids = Entry.joins(:importer)
                            .where("(release_date < ? OR (release_date IS NULL AND import_date < ?)) AND companies.drawback_customer = false",
                                   5.years.ago, 5.years.ago - 6.months).ids

    self.purge non_drawback_ids | all_entry_ids
  end

  def self.purge entry_ids
    bucket = MasterSetup.secrets["kewill_imaging"].try(:[], "s3_bucket")

    entry_ids.each do |id|
      entry = Entry.where(id: id).first
      # entry could be nil if something deleted it
      next if entry.nil?
      Lock.db_lock(entry) do
          delete_s3_imaging_files(bucket, entry) if bucket.present?

          EntryPurge.create!(broker_reference: entry.broker_reference,
                             country_iso: entry.import_country.try(:iso_code),
                             source_system: entry.source_system,
                             date_purged: Time.zone.now)
          entry.destroy
      end
    rescue StandardError => e
        e.log_me ["Entry could not be deleted, #{entry.broker_reference}"]
    end
  end

  def self.delete_s3_imaging_files bucket, entry
    prefix = nil

    if entry.source_system == "Fenix"
      prefix = "FenixImaging/#{entry.broker_reference}"
    elsif entry.source_system == "Alliance"
      prefix = "KewillImaging/#{entry.broker_reference}"
    end

    # We don't want to whipe out the entire bucket if the prefix is blank
    return if prefix.nil?

    OpenChain::S3.each_file_in_bucket(bucket, max_files: nil, prefix: prefix) do |key, version|
      OpenChain::S3.delete(bucket, key, version)
    end
  end

end; end