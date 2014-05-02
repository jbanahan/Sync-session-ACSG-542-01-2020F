require 'open_chain/xl_client'
require 'open_chain/tariff_finder'

class PartNumberCorrelation < ActiveRecord::Base
  has_one :attachment, as: :attachable, dependent: :destroy
  belongs_to :user

  attr_accessible :starting_row, :part_column, :part_regex, 
    :finished_time, :attachment, :entry_country_iso, :importers

  def self.can_view?(user)
    user.view_entries? && user.company.master?
  end

  def process(importer_ids)
    begin
      xls_file = self.attachment.attached
      xlc = OpenChain::XLClient.new(xls_file.path)
      importers = Company.where(id: importer_ids).to_a
      country = Country.find_by_iso_code(self.entry_country_iso)
      tf = OpenChain::TariffFinder.new(country, importers)

      #note: indexed at zero
      product_column_number = alphabet_column_to_numeric_column(self.part_column)

      rows_used_originally = xlc.get_row(0, 0).length
      current_row = 1

      xlc = add_additional_column_headings(xlc, rows_used_originally)
      xlc.all_row_values(0) do |row|
        if current_row < self.starting_row
          current_row += 1
        else
          part_number = xlc.get_cell(0, current_row - 1, product_column_number, true)
          regex = Regexp.new(self.part_regex)
          part_number = regex.match(part_number)[0] unless self.part_regex.blank?

          r = tf.find_by_style(part_number)

          if r
            xlc.set_cell(0, current_row - 1, rows_used_originally, r.mid)
            xlc.set_cell(0, current_row - 1, rows_used_originally + 1, r.hts_code)
            xlc.set_cell(0, current_row - 1, rows_used_originally + 2, r.country_origin_code)
          else
            xlc.set_cell(0, current_row - 1, rows_used_originally, "")
            xlc.set_cell(0, current_row - 1, rows_used_originally + 1, "")
            xlc.set_cell(0, current_row - 1, rows_used_originally + 2, "")
          end
          current_row += 1
        end
      end
      xlc.save
      self.finished_time = Time.now; self.save!
      self.user.messages.create!(subject: "Part Number Correlation Report Finished", 
        body: "<p>Your report is complete.  You can download the updated file by 
        <a href='/attachments/#{self.attachment.id}/download'>clicking here</a>.</p>
        <p>You can view the full status page by 
        <a href='/part_number_correlations'>clicking here</a>.</p>")

    rescue
      self.user.messages.create!(subject: "ERROR: Part Number Correlation Report", 
        body: "<p>We could not complete the processing of this report due to an error.</p>
        <p>You can view the full status page by 
        <a href='/part_number_correlations'>clicking here</a>.</p>")      
    end
  end

  def add_additional_column_headings(xlc, rows_used)
    xlc.set_cell(0, 0, rows_used, "MID")
    xlc.set_cell(0, 0, rows_used + 1, "HTS Code")
    xlc.set_cell(0, 0, rows_used + 2, "Country of Origin Code")
    xlc
  end

  def alphabet_column_to_numeric_column(column_heading)
    #Note that the return value is indexed at 0. A=>0, B=>1, C=>2, etc...
    alphabet = '0abcdefghijklmnopqrstuvwxyz'
    total_length = column_heading.length-1
    sum = 0
    column_heading.downcase.chars.each do |character|
        position_value = alphabet.index(character)
        contribution = position_value* (26**total_length)
        sum += contribution
        total_length -= 1
    end
    sum - 1
  end
end