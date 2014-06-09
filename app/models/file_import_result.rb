class FileImportResult < ActiveRecord::Base
  belongs_to :imported_file
  belongs_to :run_by, :class_name => "User"
  has_many :change_records, :order => "failed DESC, record_sequence_number ASC"

  after_save :update_changed_object_count

  def can_view?(user)
    return self.imported_file.can_view?(user)
  end

  def self.download_results(include_all, user_id, fir, delayed = false)
    fir = fir.is_a?(Numeric) ? FileImportResult.find(fir) : fir
    name = fir.imported_file.try(:attached_file_name).nil? ? "Log for File Import Results #{Time.now.to_date.to_s}" : "Log for " + File.basename(fir.imported_file.attached_file_name,File.extname(fir.imported_file.attached_file_name)) + " - Results"
    
    wb = fir.create_excel_report(include_all, name)

    Tempfile.open([name, '.xls']) do |t|
      wb.write(t)
      t.rewind
      if not delayed
        yield t
      else
        u = User.find(user_id)
        a = Attachment.create!(attached: t, uploaded_by: u, attachable: fir, attached_file_name: name + ".xls")
        u.messages.create!(subject: "File Import Result Prepared for Download", body: "The file import result report that you requested is finished.  To download the file directly, <a href='/attachments/#{a.id}/download'>click here</a>.")
      end
    end
  end 

  def create_excel_report(include_all, name)
    wb = XlsMaker.create_workbook(name, ["Record Number", "Status", "Messages"])
    sheet = wb.worksheet 0
    row_number = 1
    self.change_records.each do |cr|
      next if ((!include_all) && (!cr.failed?))
      messages = self.collected_messages(cr, !include_all)
      column_number = -1
      sheet[row_number, column_number+=1] = cr.record_sequence_number.to_s
      sheet[row_number, column_number+=1] = cr.failed? ? "Error" : "Success"
      sheet[row_number, column_number+=1] = messages[0]
      sheet.row(row_number).height = 12 * messages[1]
      row_number += 1
    end
    wb
  end

  def collected_messages(change_record, errors_only)
    combined_messages = ""
    message_count = 0
    change_record.change_record_messages.each do |crm|
      if errors_only
        if crm.message.downcase.starts_with?("error:")
            combined_messages += crm.message + "\n"
            message_count += 1
        end
      else
        unless crm.message.blank?
          combined_messages += crm.message + "\n"
          message_count += 1
        end
      end
    end
    [combined_messages.chop, message_count]
  end
  
  def changed_objects search_criterions=[]
    cm = self.imported_file.core_module
    k = Kernel.const_get cm.class_name
    r = k.select("DISTINCT `#{cm.table_name}`.*").joins(:change_records).where('change_records.file_import_result_id = ?',self.id)
    search_criterions.each do |sc|
      r = sc.apply r 
    end
    r.to_a
  end

  # return the total minutes to process the file or nil if the file does not have a start_at and finish_at value
  # returns 1 (never 0) if the time is less than one minute
  def time_to_process
    return nil unless self.started_at && self.finished_at
    seconds = self.finished_at - self.started_at
    minutes = (seconds/60).round
    minutes == 0 ? 1 : minutes
  end
  def error_count
    self.change_records.where(:failed=>true).count
  end

  def update_changed_object_count
    if @changed_count_updated #keeps the query from being run on the second save
      @changed_count_updated = false
    end
    changed_count = self.changed_objects.count
    if changed_count != self.changed_object_count
      self.changed_object_count = changed_count
      @changed_count_updated = true
      self.save
    end
  end
end
