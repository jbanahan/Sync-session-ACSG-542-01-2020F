require 'open_chain/random_audit_generator'

# This class takes a search setup, runs the search and then outputs it 
# in the desired format (by default, the format specified in the search_setup itself).
class SearchWriter

  attr_reader :output_format, :search_setup, :user

  def initialize search_setup, user: nil, output_format: nil
    @search_setup = search_setup
    @user = user.presence || search_setup.user
    @output_format = initialize_output_format(search_setup, output_format)
  end

  # Runs the given search setup, writing it to the io object provided.  If a block is given a tempfile
  # yielded to the caller and the Tempfile is cleaned up automatically, otherwise the tempfile is
  # returned and it is the calller's responsibility to clean up.
  def self.write_search search_setup, io, user: nil, output_format: nil, max_results: nil, audit: nil
    writer = SearchWriter.new(search_setup, user: user, output_format: output_format)
    writer.write_search io, max_results: max_results, audit: audit
    io.flush

    nil
  end

  def write_search io, max_results: nil, audit: nil
    builder = create_builder
    result_count = 0
    search_query = SearchQuery.new(@search_setup, @user)

    query_opts = {raise_max_results_error: true}
    query_opts[:per_page] = max_results if max_results.to_i > 0

    results = []
    search_query.execute(query_opts) do |row_hash|
      results << row_hash
      result_count += 1
    end

    create_sheets results, builder, @search_setup, audit, @user

    builder.write io
    io.flush

    log_audit builder, io, @search_setup, @user.id if audit

    result_count
  end

  private

    def log_audit builder, tempfile, ss, user_id
      # copy existing file
      Tempfile.open([File.basename(tempfile.path, '.*'), File.extname(tempfile.path)]) do |t|
        tempfile.rewind
        IO.copy_stream tempfile, t
        t.flush
        Attachment.add_original_filename_method(t, tempfile.original_filename)
        RandomAudit.create! attached: t, search_setup: ss, module_type: ss.module_type, 
                            report_name: t.original_filename, report_date: Time.zone.now, user_id: user_id
      end
    end

    def create_sheets results, builder, search_setup, audit, user
      if audit
        audit_results = OpenChain::RandomAuditGenerator.run(results, audit['percent'], audit['record_type'])
        create_sheet_from_collection audit_results, "Audit", builder, search_setup, user
        # CSV (for obvious reasons) can't have results added as another tab
        if builder.output_format != :csv 
          create_sheet_from_collection results, "Results", builder, search_setup, user
        end
      else
        create_sheet_from_collection results, "Results", builder, search_setup, user
      end
      # CSV can't have criterions added as another tab
      if builder.output_format != :csv
        generate_criteria_tab builder, @search_setup, audit, @user
      end
    end    

    def create_sheet_from_collection collection, title, builder, search_setup, user
      result_class = search_setup.core_module.klass
      column_model_fields = build_column_model_fields search_setup
      column_styles = build_column_styles search_setup, column_model_fields
      sheet = initialize_sheet(title, builder, search_setup, column_model_fields, user)
      collection.each{ |c| write_result_row builder, sheet, @search_setup, result_class, c, column_styles }
      builder.freeze_horizontal_rows sheet, 1
      builder.apply_min_max_width_to_columns sheet
    end

    def write_result_row builder, sheet, search_setup, result_class, search_query_hash, column_styles
      row = search_query_hash[:result]
      strip_times(row) if search_setup.no_time?

      if search_setup.include_links?
        row << builder.create_link_cell(result_class.excel_url(search_query_hash[:row_key]))
      end

      builder.add_body_row sheet, row, styles: column_styles
      nil
    end

    def strip_times result_row
      result_row.each_with_index do |val, index|
        if val.respond_to?(:acts_like_time?) && val.acts_like_time?
          # We can just do a to_date here because we're assuming that we're running in the context
          # of the user's Timezone (.ie Time.zone = User.time_zone).  So, we're either
          # running in a web context or inside a User.run_with_user_settings block
          result_row[index] = val.to_date
        end
      end
      result_row
    end

    def initialize_sheet title, builder, search_setup, column_model_fields, user
      builder.create_sheet title, headers: build_header_row(search_setup, column_model_fields, user)
    end

    def build_header_row search_setup, column_model_fields, user
      headers = []

      headers = column_model_fields.map do |mf|
        mf.can_view?(user) ? mf.label : ModelField.disabled_label
      end

      headers << "Links" if search_setup.include_links?

      headers
    end

    def build_column_model_fields search_setup
      search_setup.search_columns.order(:rank).map {|col| col.model_field }
    end

    def build_column_styles search_setup, column_model_fields
      column_model_fields.map {|mf| style_for_model_field search_setup, mf }
    end

    def style_for_model_field search_setup, model_field
      case model_field.data_type
      when :date
        :default_date
      when :datetime
        search_setup.no_time? ? :default_date : :default_datetime
      else 
        nil
      end
    end

    def generate_criteria_tab builder, search_setup, audit, user
      sheet = builder.create_sheet "Search Parameters", headers: ["Parameter Name", "Parameter Value"]
      builder.add_body_row sheet, ["User Name", user.full_name]
      builder.add_body_row sheet, ["Report Run Time", Time.zone.now], styles: [nil, :default_datetime]
      builder.add_body_row sheet, ["Customer", user.company.name]

      search_setup.search_criterions.each do |criterion|
        builder.add_body_row(sheet, create_criterion_row(criterion))
      end

      if audit
        builder.add_body_row sheet, ["Audit Percentage", audit['percent']]
        builder.add_body_row sheet, ["Dataset to Audit", audit['record_type']]
      end

      builder.apply_min_max_width_to_columns sheet
      
      nil
    end

    def create_criterion_row criterion
      row = [criterion.model_field.label]
      # Excel has a limit on the cell display length of 1024 chars.  There's also a hardlimit on the number of newlines at 253 (why?)
      # and 32K chars for xlsx and something less than that for xls.

      # I'd like to keep the display showing the same as what's in the formula bar, so we're going to trim the value and expand it horizontally
      # across the row if the cell lenght is more than 1024.
      value = "#{criterion.operator_label} #{criterion.value}"
      newline_count = value.count("\n")
      if value.length < 1024 && newline_count < 152
        row << value
      else
        newline_count = 0
        buffer = ""
        cells = []
        # The only real criterion type that should cause this much data is the one-of that's a value per line...
        # Therefore, just split per line and start length / newline counting
        index = 0
        value.each_line do |line|
          index += 1
          if (buffer.length + line.length >= 1024) || (index % 152 == 0)
            cells << buffer.chomp
            buffer = ""
            index = 1
          end

          # There's a possibility that someone keyed a single row that's more than 1024 chars...if so, just chop it at 1024
          if line.length > 1024
            line = line[0..1023]
          end

          buffer += line
        end

        if buffer.length > 0
          buffer.chomp! if buffer[-1] == "\n"
          cells << buffer
        end

        row.push *cells
      end

      row
    end

    def initialize_output_format search_setup, output_format_opt
      output = (output_format_opt.presence || search_setup.download_format).to_s.downcase

      # Default to using xlsx if not supplied
      if output.blank?
        output = "xlsx"
      end

      output
    end

    def create_builder
      case @output_format
      when "csv"
        return CsvBuilder.new
      when "xls"
        return XlsBuilder.new
      else
        return XlsxBuilder.new
      end
    end
end
