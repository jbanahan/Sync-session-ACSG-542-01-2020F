require 'open_chain/search_base'
class CustomReport < ActiveRecord::Base
  include OpenChain::SearchBase
  has_many :search_criterions, :dependent=>:destroy
  has_many :search_columns, :dependent=>:destroy
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

  def column_fields_available user
    #expects subclass to implement static version of this method
    self.class.column_fields_available user
  end

  def xls_file run_by, file=Tempfile.new([(self.name.blank? ? "report" : self.name),"xls"] )
    @listener = XlsListener.new 
    run run_by
    @listener.workbook.write file.path
    file
  end
  
  #runs the resport in xls format.  This method gives duck type compatibility with the reports in open_chain/reports so ReportResult.execute_report can call htem
  def run_report run_by, *p
    xls_file run_by
  end

  def csv_file run_by, file=Tempfile.new([(self.name.blank? ? "report" : self.name),"csv"])
    @listener = ArraysListener.new
    run run_by
    a = @listener.arrays
    a.each do |line|
      file.write line.to_csv
    end
    file.flush
    file
  end

  def to_arrays run_by, row_limit=nil
    @listener = ArraysListener.new
    run run_by, row_limit
    @listener.arrays
  end

  def write row, column, content
    @listener.write row, column, content
  end

  def write_hyperlink row, column, url, alt_text=nil
    @listener.write_hyperlink row, column, url, alt_text 
  end
  
  def heading_row row
    @listener.heading_row row
  end


  private 
  class ArraysListener
    attr_accessor :data
    def initialize
      self.data = {}
    end
    def write row, column, content
      self.data[row] ||= {}
      self.data[row][column] = content
    end
    def write_hyperlink row, column, url, alt_text
      write row, column, url
    end
    def heading_row row
      #do nothing
    end
    def arrays
      r_val = []
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
    def initialize 
      self.workbook = Spreadsheet::Workbook.new
      @sheet = self.workbook.create_worksheet
    end

    def write row, column, content
      c = content
      c = c.to_s.to_f if c.is_a?(BigDecimal)
      @sheet.row(row)[column] = c
      @sheet.row(row).set_format(column,XlsMaker::DATE_FORMAT) if c.is_a?(Date) 
      update_column_width column, (c.is_a?(Date) ? 10 : c.to_s.size)
    end

    def write_hyperlink row, column, url, alt_text
      c = alt_text.blank? ? url : alt_text
      c = c.to_s.to_f if c.is_a?(BigDecimal)
      @sheet.row(row)[column] = Spreadsheet::Link.new(url,c)
      @sheet.row(row).set_format(column,XlsMaker::DATE_FORMAT) if c.is_a?(Date) 
      update_column_width column, (c.is_a?(Date) ? 10 : c.to_s.size)
    end

    def heading_row row_number
      @sheet.row(row_number).default_format = XlsMaker::HEADER_FORMAT 
    end
    def update_column_width column_number, content_width
      target_width = 8
      target_width = content_width if content_width > 8
      target_width = 23 if target_width > 23
      @column_widths ||= {}
      current_width = @column_widths[column_number]
      @column_widths[column_number] = target_width unless !current_width.nil? && current_width > target_width
      @sheet.column(column_number).width = target_width unless @column_widths[column_number]==current_width
    end
  end
end
