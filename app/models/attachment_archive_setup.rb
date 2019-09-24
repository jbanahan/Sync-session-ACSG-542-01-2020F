# == Schema Information
#
# Table name: attachment_archive_setups
#
#  archive_scheme                  :string(255)
#  combine_attachments             :boolean
#  combined_attachment_order       :text(65535)
#  company_id                      :integer
#  created_at                      :datetime         not null
#  end_date                        :date
#  id                              :integer          not null, primary key
#  include_only_listed_attachments :boolean
#  send_as_customer_number         :string(255)
#  send_in_real_time               :boolean
#  start_date                      :date
#  updated_at                      :datetime         not null
#
# Indexes
#
#  index_attachment_archive_setups_on_company_id  (company_id)
#

class AttachmentArchiveSetup < ActiveRecord::Base
  attr_accessible :company_id, :start_date, :combine_attachments, 
    :combined_attachment_order, :include_only_listed_attachments, 
    :send_in_real_time, :archive_scheme, :end_date, :send_as_customer_number

  belongs_to :company

  ARCHIVE_SCHEMES ||= [["Invoice Date Prior To 30 Days Ago", "MINUS_30"], ["Invoice Date Prior to This Month", "PREVIOUS_MONTH"], ["Release Date Prior to This Month", "RELEASE_PREVIOUS_MONTH"]]
  # The override allows for manually making archives over specific file lists
  attr_accessor :broker_reference_override

  # This method returns all valid archive setups for a particular company.  This includes the setup associated with the company
  # or any parent company.
  def self.setups_for company
    setups = AttachmentArchiveSetup.where("company_id IN (SELECT distinct c.id FROM companies c LEFT OUTER JOIN linked_companies l on c.id = l.parent_id 
WHERE c.id = ? OR l.child_id = ?)", company.id, company.id).to_a

    # Lets return the company's setup first (since the first setup is the one  callers to this will use most)
    # and we should prioritize the company's own setup over the parent in cases where each have one.
    company_setup = nil
    setups.reject! do |s| 
      if s.company_id == company.id 
        company_setup = s
        true
      else
        false
      end
    end

    setups.unshift company_setup if company_setup
    setups
  end

  #creates an archive with files for this importer that are on entries up to the max_size_in_bytes size
  def create_entry_archive! name, max_size_in_bytes
    archive = nil
    AttachmentArchiveSetup.transaction do
      archive = AttachmentArchive.create! :name=>name, :start_at=>Time.now, :company_id=>self.company_id 
      running_size = 0
      available_entry_files(broker_reference_override: @broker_reference_override).each do |att|
        running_size += att.attached_file_size
        break if running_size > max_size_in_bytes
        archive.attachment_archives_attachments.create!(:attachment_id=>att.id,:file_name=>att.unique_file_name)
      end
    end
    archive
  end

  def self.next_archive_name company
    num = 1
    arch = company.attachment_archives.order("created_at DESC").first
    num = arch.name.split("-").last.to_i + 1 if arch
    return "#{company.name.gsub(/\W/,'')}-#{num}"
  end

  # This method creates archive(s) for the given customer and the given reference numbers.  It does NOT 
  # utilize any of the archive setup start / end dates (in fact, a setup doesn't even need to exist).
  # If any files have already been archived, they will be removed from the previous archive.
  def self.create_entry_archives_for_reference_numbers! max_archive_size_in_bytes, importer, reference_numbers
    archives = []
    setup = importer.attachment_archive_setup

    current_archive = nil
    all_entries = Entry.where(importer_id: importer.id, broker_reference: reference_numbers).order(:arrival_date).to_a
    finished_archiving_docs = false
    entry_counter = 0

    while !finished_archiving_docs
      ActiveRecord::Base.transaction do 
        Lock.db_lock(importer) { current_archive = AttachmentArchive.create! start_at: Time.zone.now, company_id: importer.id, name: next_archive_name(importer)  }
        Lock.db_lock(current_archive) do 
          current_archive_size = 0

          (entry_counter..(all_entries.length - 1)).each do |counter|
            archived = false

            catch (:archive_too_big) do 
              # add_entry_docs_to_archive throws 'archive_too_big' if the current archive doesn't have enough space left in it to add
              # all of this entries docs.  If that happens, we basically want to finish the archive, get back to the outer while loop
              # and start a new archive.
              attachments_size = add_entry_docs_to_archive(setup, current_archive, current_archive_size, max_archive_size_in_bytes, all_entries[counter])
              # This flag lets us know that the docs were added to the archive
              archived = true
              # Increment the counter the next loop iteration uses the next entry
              entry_counter += 1
              # Keep track of how many bytes we've added to the current archive
              current_archive_size += attachments_size
            end

            # If we couldn't archive the docs, then it means we've hit the max archive size..in which case, we break this loop and let the outer loop
            # run and create another archive
            break unless archived
          end
          archives << current_archive

          # If the archive size doesn't go up, it means we could the docs for a single entry in the archive...which is bad, so bomb
          raise "Unable to fit any documents in a single archive.  Try setting the archive size higher than #{max_archive_size_in_bytes}." if current_archive_size == 0

          finished_archiving_docs = entry_counter >= all_entries.length
        end
      end
    end
      
    archives
  end

  #are there any more entry attachments available to be put on archives
  def entry_attachments_available?
    entry_attachments_available_count > 0
  end

  def entry_attachments_available_count
    available_entry_files(broker_reference_override: @broker_reference_override, countable_query: true).count
  end

  private
  def available_entry_files broker_reference_override: nil, countable_query: false
    non_stitchable_attachments = Attachment.stitchable_attachment_extensions.collect {|ext| self.class.sanitize_sql_array(["attachments.attached_file_name NOT like ?", "%#{ext}"]) }.join (" AND ")

    select_values = countable_query ? "id" : "*"

    a = Attachment.select("distinct attachments.#{select_values}").
      joins("INNER JOIN entries on entries.id = attachments.attachable_id AND attachments.attachable_type = \"Entry\"").
      joins("LEFT OUTER JOIN attachment_archives_attachments on attachments.id = attachment_archives_attachments.attachment_id").
      # Rather than relying on a join against the archive setup table for a flag, which would mean for any customer that switched off the packet we'd instantly then 
      # have thousands of back images to fill in for archive, What we're doing here is preventing the use of any other documents in cases where the entry has 
      # one of our prepared / stitched Archive Packets already present
      joins(self.class.sanitize_sql_array(["LEFT OUTER JOIN attachments arc_packet ON attachments.attachable_id = arc_packet.attachable_id and arc_packet.attachment_type = ?", Attachment::ARCHIVE_PACKET_ATTACHMENT_TYPE])).
      where("arc_packet.id IS NULL OR arc_packet.id = attachments.id OR (#{non_stitchable_attachments})").
      where("attachment_archives_attachments.attachment_id is null").
      where("attachments.is_private IS NULL OR attachments.is_private = 0").
      where("entries.importer_id = ?",self.company_id).
      order("entries.arrival_date ASC")

    # If an override was given, then we should use that list as the sole decider of which files for the importer
    # to archive (.ie don't bother with the invoice date logic)
    if broker_reference_override && broker_reference_override.length > 0
      a = a.where("entries.broker_reference IN (?)", broker_reference_override)
    else
      case (self.archive_scheme.presence || "MINUS_30").to_s.upcase
      when "PREVIOUS_MONTH"
        a = invoice_date_prior_to_this_month(a, self.start_date, self.end_date)
      when "MINUS_30"
        a = invoice_date_prior_to_30_days_ago(a, self.start_date, self.end_date)
      when "RELEASE_PREVIOUS_MONTH"
        a = release_date_prior_to_this_month(a, self.start_date, self.end_date)
      else
        raise "Invalid document archive scheme encountered: #{self.archive_scheme}"
      end
    end

    a
  end

  def release_date_prior_to_this_month base_query, archive_start_date, archive_end_date
    days_ago = (ActiveSupport::TimeZone["America/New_York"].now.at_beginning_of_month - 1.second)

    release_date_based_query(base_query, archive_start_date, archive_end_date, days_ago)
  end

  def release_date_based_query base_query, archive_start_date, archive_end_date, days_ago
    base_query = add_end_date_logic(base_query, "entries", "release_date", archive_end_date, days_ago)
    add_start_date_logic(base_query, "entries", "release_date", archive_start_date)
  end

  def invoice_date_prior_to_this_month base_query, archive_start_date, archive_end_date
    days_ago = (ActiveSupport::TimeZone["America/New_York"].now.at_beginning_of_month - 1.day).to_date
    invoice_date_based_query(base_query, archive_start_date, archive_end_date, days_ago)
  end

  def invoice_date_prior_to_30_days_ago base_query, archive_start_date, archive_end_date
    days_ago = (ActiveSupport::TimeZone["America/New_York"].now.midnight - 30.days).to_date
    invoice_date_based_query(base_query, archive_start_date, archive_end_date, days_ago)
  end

  def invoice_date_based_query base_query, archive_start_date, archive_end_date, days_ago
    base_query = base_query.joins("INNER JOIN broker_invoices ON entries.id = broker_invoices.entry_id")
    base_query = add_end_date_logic(base_query, "broker_invoices", "invoice_date", archive_end_date, days_ago)
    add_start_date_logic(base_query, "broker_invoices" , "invoice_date", archive_start_date)
  end

  def add_end_date_logic base_query, table_name, end_column, end_date, days_ago
    if end_date && days_ago && end_date < days_ago
      days_ago = end_date
    end

    base_query.where("#{ActiveRecord::Base.connection.quote_table_name(table_name)}.#{ActiveRecord::Base.connection.quote_column_name(end_column)} <= ?", days_ago)
  end

  def add_start_date_logic base_query, table_name, start_column, start_date
    base_query.where("#{ActiveRecord::Base.connection.quote_table_name(table_name)}.#{ActiveRecord::Base.connection.quote_column_name(start_column)} >= ?", start_date)
  end


  def self.add_entry_docs_to_archive setup, archive, current_archive_size, max_archive_size, entry
    archivable_attachments = archivable_attachments_for_entry(setup, entry)
    attachments_size = archivable_attachments.map { |a| a.attached_file_size.to_f }.sum

    if current_archive_size + attachments_size > max_archive_size
      throw :archive_too_big
    else
      archivable_attachments.each do |a|
        # We need to remove the attachment from any existing archives, then we'll add it to this one
        a.attachment_archives_attachments.destroy_all
        
        archive.attachment_archives_attachments.create! attachment_id: a.id, file_name: a.unique_file_name
      end
    end

    attachments_size
  end

  def self.archivable_attachments_for_entry setup, entry
    # Eliminate any private docs - don't archive them for the customer, since they shouldn't see them.
    attachments = entry.attachments.where("is_private IS NULL OR is_private = 0").to_a
    archivable_attachments = []

    # If the customer is using our service where we stitch pdfs/tifs together into a single pdf, then we should only 
    # be pulling the archive packet, along with any other docs that can't be combined.  Like excel or word docs.
    if setup&.combine_attachments?
      archive_packet = attachments.find {|a| a.attachment_type == Attachment::ARCHIVE_PACKET_ATTACHMENT_TYPE}
      if archive_packet
        # We need to now also include any attachments that could not be part of the archive packet (.ie excel, zip, word docs)
        archivable_attachments << archive_packet
        attachments.each {|a| archivable_attachments << a if !a.stitchable_attachment?}
      else
        # It's possible the archive packet couldn't be created due to a malformed pdf/tif etc causing the stitch process to be unable 
        # to build the file.  In that case, we want to include all the docs.
        archivable_attachments = attachments
      end
    else
      archivable_attachments = attachments
    end

    archivable_attachments
  end
end
