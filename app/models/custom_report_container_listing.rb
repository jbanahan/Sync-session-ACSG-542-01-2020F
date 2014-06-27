class CustomReportContainerListing < CustomReport
  def self.template_name
    "Container Listing"
  end
  def self.description
    "Show all entries with a row for each container"
  end
  def self.column_fields_available user
    CoreModule::ENTRY.model_fields(user).values
  end
  def self.criterion_fields_available user
    CoreModule::ENTRY.model_fields(user).values
  end
  def self.can_view? user
    user.view_entries?
  end
  def run run_by, row_limit = nil
    row_cursor = -1
    col_cursor = 0

    #HEADINGS
    headers = ["Container Number"] + self.search_columns.map {|sc| sc.model_field.label}

    write_headers (row_cursor += 1), headers

    entries = Entry.search_secure run_by, Entry.group("entries.id")
    self.search_criterions.each {|sc| entries = sc.apply(entries)}
    
    entries.each do |ent|
      container_numbers = ent.container_numbers
      container_numbers = "N/A" if container_numbers.blank?
      container_numbers.each_line do |cn|
        return if row_limit && row_cursor >= row_limit

        row_data = [cn.strip] + self.search_columns.to_a
        write_row (row_cursor += 1), ent, row_data, run_by
      end
    end

    write_no_data (row_cursor +=1) if row_cursor == 0
    nil
  end
end
