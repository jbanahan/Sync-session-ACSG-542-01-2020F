# == Schema Information
#
# Table name: custom_reports
#
#  created_at         :datetime         not null
#  id                 :integer          not null, primary key
#  include_links      :boolean
#  include_rule_links :boolean
#  name               :string(255)
#  no_time            :boolean
#  type               :string(255)
#  updated_at         :datetime         not null
#  user_id            :integer
#
# Indexes
#
#  index_custom_reports_on_type     (type)
#  index_custom_reports_on_user_id  (user_id)
#

require 'open_chain/search_base'
require 'dry/core/descendants_tracker'
require 'open_chain/url_support'

class CustomReport < ActiveRecord::Base
  extend Dry::Core::DescendantsTracker
  include OpenChain::SearchBase
  include OpenChain::UrlSupport

  attr_accessible :include_links, :include_rule_links, :name, :no_time, :type, :user_id, :user,
  :search_criterions_attributes, :sort_criterions_attributes, :search_columns_attributes, :search_schedules_attributes

  has_many :search_criterions, :dependent=>:destroy
  has_many :search_columns, -> { order(:rank) }, :dependent=>:destroy
  has_many :search_schedules, :dependent=>:destroy
  has_many :report_results
  belongs_to :user, :inverse_of=>:custom_reports

  validate :scheduled_reports_have_parameters

  accepts_nested_attributes_for :search_criterions, :allow_destroy => true,
    :reject_if => lambda { |a|
      r_val = false
      [:model_field_uid, :operator].each { |f|
        r_val = true if a[f].blank?
      }
      r_val
    }
  accepts_nested_attributes_for :search_columns, :allow_destroy => true,
    :reject_if => lambda { |a| a[:model_field_uid].blank? }
  accepts_nested_attributes_for :search_schedules, :allow_destroy => true,
    :reject_if => lambda { |a| a[:email_addresses].blank? &&
      a[:ftp_server].blank? &&
      a[:_destroy].blank?
    }

  scope :for_user, lambda { |u| where(user: u) }
  attr_reader :preview_run

  # Stupid hack because rails protects the type attribute by default (not 100% sure why - default polymorhpism column name?)...
  # Hindsight being what it is, we should have used a different attribute name to determine the report's type
  # like say, report_type.
  def self.attributes_protected_by_default
    ["id"]
  end

  def column_fields_available user
    # expects subclass to implement static version of this method
    fields = self.class.column_fields_available user
    fields.select {|mf| mf.can_view?(user)  && mf.user_accessible?}
  end

  def criterion_fields_available user
    fields = self.class.criterion_fields_available user
    fields.select {|mf| mf.can_view?(user) && mf.user_accessible?}
  end

  def xlsx_file run_by, row_limit: nil, file: Tempfile.new([(self.name.blank? ? "report" : clean_filename(self.name)), ".xlsx"] )
    @listener = XlsxListener.new self.no_time?
    run run_by, max_results(run_by, row_limit)
    workbook = @listener.build_xlsx
    workbook.write(file)
    [file, @listener.blank_file?]
  end

  def xls_file run_by, row_limit: nil, file: Tempfile.new([(self.name.blank? ? "report" : clean_filename(self.name)), ".xls"] )
    @listener = XlsListener.new self.no_time?
    run run_by, max_results(run_by, row_limit)
    @listener.workbook.write file.path
    [file, @listener.blank_file?]
  end

  # runs the resport in xls format.  This method gives duck type compatibility with the reports in open_chain/reports so ReportResult.execute_report can call htem
  def run_report run_by, *p
    xlsx_file run_by
  end

  def csv_file run_by, row_limit: nil, file: Tempfile.new([(self.name.blank? ? "report" : clean_filename(self.name)), ".csv"])
    @listener = ArraysListener.new self.no_time?
    run run_by, max_results(run_by, row_limit)
    a = @listener.arrays
    a.each do |line|
      file.write line.to_csv
    end
    file.flush
    [file, @listener.blank_file?]
  end

  def clean_filename str
    str.gsub(/[\/~#&\*\%{\}\\:<>\?\+\|"']/, '_')
  end

  def to_arrays run_by, row_limit: nil, preview_run: false
    @listener = ArraysListener.new self.no_time?, false
    @preview_run = preview_run
    run run_by, max_results(run_by, row_limit)
    @listener.arrays
  ensure
    @preview_run = nil
  end

  def write row, column, content
    @listener.write row, column, content
  end

  def write_columns row, starting_column, content_array
    content_array.each do |c|
      @listener.write row, starting_column, c
      starting_column += 1
    end
  end

  def write_hyperlink row, column, url, alt_text=nil
    @listener.write_hyperlink row, column, url, alt_text
  end

  def heading_row row
    @listener.heading_row row
  end

  # This is a no-op for CSV outputs
  def add_tab tab_name
    @listener.add_tab tab_name
  end

  protected
    def validate_access run_by
      raise "User #{run_by.username} does not have permission to view this report." unless self.class.can_view?(run_by)
      true
    end

    def setup_report_query active_record_class, run_by, row_limit, opt = {}
      opt = {:distinct => true}.merge opt
      query = active_record_class.all
      query = active_record_class.select("DISTINCT `#{active_record_class.table_name}`.*") if opt[:distinct]

      search_criterions.each {|sc| query = sc.apply query}
      query = active_record_class.search_secure run_by, query
      query = query.limit(row_limit) if row_limit

      query
    end

    def write_headers row, headers, run_by
      heading_row row
      values = []
      values << "Web Links" if self.include_links?
      values << "Business Rule Links" if self.include_rule_links?

      # Look for either search columns or strings in the headers array
      # Allows you to easily append custom headers if needed ie. -> self.search_columns + ['Custom1', 'Custom2']
      headers.each do |v|
        mf = model_field(v)
        if mf
          values << (mf.can_view?(run_by) ? mf.label : ModelField.disabled_label)
        else
          values << v
        end
      end

      write_columns row, 0, values
    end

    def write_row row, row_object, values, run_by
      link_offset = 0
      if self.include_links?
        write_hyperlink(row, link_offset, row_object.excel_url, "Web View")
        link_offset += 1
      end

      if self.include_rule_links?
        write_hyperlink(row, link_offset, validation_results_url(obj: row_object), "Web View")
        link_offset += 1
      end

      content = []
      values.each do |v|
        mf = model_field(v)
        content << (mf ? mf.process_export(row_object, run_by) : v)
      end

      write_columns row, link_offset, content
    end

    def write_no_data row, message = "No data was returned for this report."
      write row, 0, message
    end

    def max_results run_by, limit
      system_max = SearchSetup.max_results(run_by)
      # Return the lesser of the system max or the "user provided" max
      limit.nil? ? system_max : [limit, system_max].min
    end

  private
  def model_field v
    return v if v.is_a?(ModelField)
    return v.model_field if v.respond_to?(:model_field)
    nil
  end

  def scheduled_reports_have_parameters
    # If there are no search criterions (or there will be zero after the save completes), then we should
    return unless self.search_criterions.find { |sc| !sc.marked_for_destruction? && !sc.destroyed? }.nil?

    if self.search_schedules.find { |ss| !ss.marked_for_destruction? && !ss.destroyed? }.present?
      self.errors.add(:base, "All reports with schedules must have at least one parameter.")
    end

    nil
  end

  class ReportListener
    def write row, column, content
      raise NotImplementedError
    end

    def write_hyperlink row, column, url, alt_text
      raise NotImplementedError
    end

    def heading_row(row)
      raise NotImplementedError
    end

    def add_tab(tab_name)
      raise NotImplementedError
    end
  end

  class XlsxListener < ReportListener
    attr_accessor :data

    def initialize(no_time = false)
      @sheets = []
      @no_time = no_time
      @sheet = Worksheet.new
      @sheets << @sheet
      @wb = XlsxBuilder.new
    end

    def blank_file?
      return true if @sheets[0].rows.blank? || @sheets[0].rows.length == 1
      @sheets[0].rows[1].cells[0].content.to_s.include?("No data was returned")
    end

    class Cell
      attr_accessor :type, :content, :url

      def initialize(type = 'normal')
        @type = type
      end

      def to_xlsx
        type == 'normal' ? content : {location: url, link_text: content, type: :hyperlink}
      end
    end

    class Row
      attr_accessor :type, :cells

      def initialize(type = 'normal')
        @type = type
        @cells = []
      end

      def to_xlsx
        return [] if cells.blank?
        cells.map {|cell| cell.nil? ? Cell.new : cell}
            .map(&:to_xlsx)
      end

      def insert_link_cell_value column, url, alt_text
        cell = get_cell_by_column(column)

        content = url.blank? ? "" : (alt_text.blank? ? url : alt_text)
        content = content.to_s.to_f if content.is_a?(BigDecimal)

        cell.url = url
        cell.content = content
        cell.type = 'hyperlink'
      end

      def create_cell column
        cell = Cell.new
        @cells[column] = cell

        cell
      end

      def get_cell_by_column column
        cell = if @cells[column].blank?
                 create_cell column
               else
                 @cells[column]
               end
        cell
      end

      def insert_cell_value column, content
        cell = get_cell_by_column column

        cell.content = content
      end
    end

    class Worksheet
      attr_accessor :sheets, :name, :rows

      def initialize(name = "Sheet 1")
        @name = name
        @rows = []
      end

      def get_or_create_row_at_index(row)
        if rows[row].blank?
          rows[row] = Row.new
        end

        rows[row]
      end
    end

    def add_tab tab_name
      # if current @sheet contains no rows we assume we are naming the first sheet
      if @sheet.rows.length > 0
        @sheet = Worksheet.new(tab_name)
        @sheets << @sheet
      else
        @sheet.name = tab_name
      end
    end

    def write row, column, content
      @row = @sheet.get_or_create_row_at_index row

      content = content.to_date if content.respond_to?(:strftime) && @no_time

      @row.insert_cell_value column, content
      @row
    end

    def write_hyperlink row, column, url, alt_text
      @row = @sheet.get_or_create_row_at_index row
      @row.insert_link_cell_value column, url, alt_text
    end

    def heading_row row_number
      # A row with `type` 'header' is a header row.
      row = @sheet.get_or_create_row_at_index(row_number)
      row.type = 'header'
    end

    def build_xlsx
      @sheets.each do |sheet|
        xlsx_sheet = @wb.create_sheet(sheet.name)
        sheet.rows.each do |row|
          if row.blank?
            @wb.add_body_row(xlsx_sheet, [])
          elsif row.type == 'header'
            @wb.add_header_row(xlsx_sheet, row.to_xlsx)
          else
            @wb.add_body_row(xlsx_sheet, row.to_xlsx)
          end
        end
      end

      @wb
    end
  end

  class ArraysListener < ReportListener
    attr_accessor :data
    def initialize no_time = false, csv_output = true
      self.data = {}
      @no_time = no_time
      @csv_output = csv_output
      @blank_file = false
    end

    def blank_file?
      return true if self.data.nil? || self.data.length == 1
      @blank_file
    end

    def write row, column, content
      @blank_file = true if content.to_s.include?("No data was returned")
      # For array based output, don't bother truncating times.  This is only
      # used on the front-end for previews, and it handles the truncation directly.
      if @csv_output && content.respond_to?(:strftime)
        content = content.strftime(@no_time ? "%Y-%m-%d" : "%Y-%m-%d %H:%M")
      end

      self.data[row] ||= {}
      self.data[row][column] = content
    end
    def write_hyperlink row, column, url, alt_text
      write row, column, url
    end
    def heading_row row
      # do nothing
    end
    def add_tab tab_name
      # do nothing
    end
    def arrays
      r_val = []
      return r_val if data.empty?
      (0..data.keys.sort.last).each do |row_num|
        row = []
        if self.data[row_num]
          (0..self.data[row_num].keys.sort.last).each do |col_num|
            v = self.data[row_num][col_num]
            row << (v.nil? ? "" : v)
          end
        end
        r_val << row
      end
      r_val
    end
  end
  class XlsListener < ReportListener
    attr_accessor :workbook
    def initialize no_time = false
      @workbook = Spreadsheet::Workbook.new
      @sheet = @workbook.create_worksheet
      @column_widths = []
      @xls_options = {no_time: no_time}
    end

    def blank_file?
      xls_report = @workbook.worksheet 0
      return true if xls_report.count == 1
      if xls_report.count == 2
        (xls_report.row(1)[0] =~ /No data was returned/).nil? ? false : true
      else false
      end
    end

    def write row, column, content
      XlsMaker.insert_cell_value @sheet, row, column, content, @column_widths, @xls_options
    end

    def write_hyperlink row, column, url, alt_text
      c = alt_text.blank? ? url : alt_text
      c = c.to_s.to_f if c.is_a?(BigDecimal)
      XlsMaker.insert_cell_value @sheet, row, column, Spreadsheet::Link.new(url, c), @xls_options
    end

    def heading_row row_number
      @sheet.row(row_number).default_format = XlsMaker::HEADER_FORMAT
    end

    def add_tab tab_name
      # If add_tab is called prior to any data being written to the tab we'll assume we're naming the first sheet
      if @sheet.row_count > 0 || @sheet.column_count > 0
        @sheet = @workbook.create_worksheet
        @sheet.name = tab_name
        @column_widths = []
      else
        @sheet.name = tab_name
      end
    end
  end
end
