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
  def self.write_search search_setup, io, user: nil, output_format: nil, max_results: nil
    writer = SearchWriter.new(search_setup, user: user, output_format: output_format)
    writer.write_search io, max_results: max_results
    io.flush

    nil
  end

  def write_search io, max_results: nil
    builder = create_builder
    column_model_fields = build_column_model_fields @search_setup
    column_styles = build_column_styles @search_setup, column_model_fields

    sheet = initialize_results_sheet(builder, @search_setup, column_model_fields, @user)

    result_count = 0
    search_query = SearchQuery.new(@search_setup, @user)
    result_class = @search_setup.core_module.klass

    query_opts = {raise_max_results_error: true}
    query_opts[:per_page] = max_results if max_results.to_i > 0

    search_query.execute(query_opts) do |row_hash|
      write_result_row builder, sheet, @search_setup, result_class, row_hash, column_styles
      result_count += 1
    end

    builder.freeze_horizontal_rows sheet, 1
    builder.apply_min_max_width_to_columns sheet

    # CSV (for obvious reasons) can't have criterions added as another tab
    if builder.output_format != :csv
      generate_criteria_tab builder, @search_setup, @user
    end

    builder.write io
    io.flush

    result_count
  end

  private 

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

    def initialize_results_sheet builder, search_setup, column_model_fields, user
      builder.create_sheet "Results", headers: build_header_row(search_setup, column_model_fields, user)
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

    def generate_criteria_tab builder, search_setup, user
      sheet = builder.create_sheet "Search Parameters", headers: ["Parameter Name", "Parameter Value"]
      builder.add_body_row sheet, ["User Name", user.full_name]
      builder.add_body_row sheet, ["Report Run Time", Time.zone.now], styles: [nil, :default_datetime]
      builder.add_body_row sheet, ["Customer", user.company.name]

      search_setup.search_criterions.each do |criterion|
        builder.add_body_row(sheet, [criterion.model_field.label, "#{criterion.operator_label} #{criterion.value}"])
      end

      builder.apply_min_max_width_to_columns sheet
      
      nil
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