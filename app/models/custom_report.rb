require 'open_chain/search_base'
class CustomReport < ActiveRecord::Base
  include OpenChain::SearchBase
  has_many :search_criterions, :dependent=>:destroy
  has_many :search_columns, :dependent=>:destroy, :order => 'rank ASC'
  has_many :search_schedules, :dependent=>:destroy
  has_many :report_results
  belongs_to :user, :inverse_of=>:custom_reports
  
  accepts_nested_attributes_for :search_criterions, :allow_destroy => true, 
    :reject_if => lambda { |a| 
      r_val = false
      [:model_field_uid,:operator].each { |f|
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
  
  scope :for_user, lambda {|u| where(:user_id => u)} 

  def column_fields_available user
    #expects subclass to implement static version of this method
    self.class.column_fields_available user
  end

  def criterion_fields_available user
    self.class.criterion_fields_available user
  end

  def xls_file run_by, file=Tempfile.new([(self.name.blank? ? "report" : self.name),".xls"] )
    @listener = XlsListener.new self.no_time?
    run run_by
    @listener.workbook.write file.path
    file
  end
  
  #runs the resport in xls format.  This method gives duck type compatibility with the reports in open_chain/reports so ReportResult.execute_report can call htem
  def run_report run_by, *p
    xls_file run_by
  end

  def csv_file run_by, file=Tempfile.new([(self.name.blank? ? "report" : self.name),".csv"])
    @listener = ArraysListener.new self.no_time?
    run run_by
    a = @listener.arrays
    a.each do |line|
      file.write line.to_csv
    end
    file.flush
    file
  end

  def to_arrays run_by, row_limit=nil
    @listener = ArraysListener.new self.no_time?, false
    run run_by, row_limit
    @listener.arrays
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
      query = active_record_class.scoped
      query = active_record_class.select("DISTINCT `#{active_record_class.table_name}`.*") if opt[:distinct]

      search_criterions.each {|sc| query = sc.apply query}
      query = active_record_class.search_secure run_by, query
      query = active_record_class.limit(row_limit) if row_limit

      query
    end

    def write_headers row, headers
      heading_row row
      values = []
      values << "Web Links" if self.include_links?

      # Look for either search columns or strings in the headers array
      # Allows you to easily append custom headers if needed ie. -> self.search_columns + ['Custom1', 'Custom2']
      headers.each do |v|
        values << ((v.is_a? String) ? v : v.model_field.label)
      end

      write_columns row, 0, values
    end

    def write_row row, row_object, values, run_by
      links = self.include_links?
      write_hyperlink(row, 0, row_object.excel_url, "Web View") if links

      content = []
      values.each do |v|
        content << (v.respond_to?(:model_field) ? v.model_field.process_export(row_object, run_by) : v)
      end

      write_columns row, (links ? 1 : 0), content
    end

    def write_no_data row, message = "No data was returned for this report."
      write row, 0, message
    end

  private 
  class ArraysListener
    attr_accessor :data
    def initialize no_time = false, csv_output = true
      self.data = {}
      @no_time = no_time
      @csv_output = csv_output
    end
    def write row, column, content
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
      #do nothing
    end
    def add_tab tab_name
      #do nothing
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
  class XlsListener
    attr_accessor :workbook
    def initialize no_time = false
      @workbook = Spreadsheet::Workbook.new
      @sheet = @workbook.create_worksheet
      @column_widths = []
      @xls_options = {no_time: no_time}
    end

    def write row, column, content
      XlsMaker.insert_cell_value @sheet, row, column, content, @column_widths, @xls_options
    end

    def write_hyperlink row, column, url, alt_text
      c = alt_text.blank? ? url : alt_text
      c = c.to_s.to_f if c.is_a?(BigDecimal)
      XlsMaker.insert_cell_value @sheet, row, column, Spreadsheet::Link.new(url,c), @xls_options
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
