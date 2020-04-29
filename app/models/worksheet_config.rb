# == Schema Information
#
# Table name: worksheet_configs
#
#  created_at  :datetime         not null
#  id          :integer          not null, primary key
#  module_type :string(255)
#  name        :string(255)
#  updated_at  :datetime         not null
#

require 'spreadsheet'

class WorksheetConfig < ActiveRecord::Base
  attr_accessible :module_type, :name, :worksheet_config_mappings_attributes

  has_many :worksheet_config_mappings, :dependent => :destroy

  validates :name, :presence => true

  accepts_nested_attributes_for :worksheet_config_mappings, :allow_destroy => true,
    :reject_if => lambda {|m|
      return false if !m[:_destroy].blank?
      (m[:model_field_uid].blank? || m[:row].blank? || m[:column].blank?)
    }

  def process(obj, data, user, opts={})
    o = {:processor => XlsWorksheetProcessor.new}.merge opts
    p = o[:processor]
    custom_data = {}
    p.data = data
    self.worksheet_config_mappings.each do |m|
      mf = ModelField.find_by_uid m.model_field_uid
      mf.process_import(obj, p.value(m.row, m.column), user)
    end
    obj.save
  end
end

class XlsWorksheetProcessor
  attr_accessor :data

  def data=(obj)
    b = Spreadsheet.open(obj)
    w = b.worksheet(0)
    @data = w
  end

  def value(row_num, col_num)
    raise "Worksheet file not set." if @data.nil?
    r = data.row(row_num)
    return nil if r.nil?
    return r[col_num]
  end
end
