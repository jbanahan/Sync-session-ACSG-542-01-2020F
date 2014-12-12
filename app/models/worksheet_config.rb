require 'spreadsheet'

class WorksheetConfig < ActiveRecord::Base
  has_many :worksheet_config_mappings, :dependent => :destroy

  validates :name, :presence => true

  accepts_nested_attributes_for :worksheet_config_mappings, :allow_destroy => true, 
    :reject_if => lambda {|m| 
      return false if !m[:_destroy].blank?
      (m[:model_field_uid].blank? || m[:row].blank? || m[:column].blank?) 
    }

  def process(obj,data,user, opts={})
    o = {:processor => XlsWorksheetProcessor.new}.merge opts
    p = o[:processor]
    custom_data = {}
    p.data = data
    self.worksheet_config_mappings.each do |m|
      mf = ModelField.find_by_uid m.model_field_uid 
      if mf.custom?
        custom_data[mf] = p.value(m.row,m.column) if mf.can_edit? user
      else
        mf.process_import(obj,p.value(m.row,m.column), user)
      end
    end
    obj.save
    custom_data.each do |mf,val|
      cv = obj.get_custom_value_by_id(mf.custom_id)
      cv.value = val
      cv.save
    end
  end
end

class XlsWorksheetProcessor
  attr_accessor :data

  def data=(obj)
    b = Spreadsheet.open(obj)
    w = b.worksheet(0)
    @data = w
  end

  def value(row_num,col_num)
    raise "Worksheet file not set." if @data.nil?
    r = data.row(row_num)
    return nil if r.nil?
    return r[col_num]
  end
end
