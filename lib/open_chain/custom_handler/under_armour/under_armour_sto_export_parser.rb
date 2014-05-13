require 'open_chain/xl_client'

# Parse Under Armour Canadian Stock Transfer Invoices for Drawback Export
module OpenChain; module CustomHandler; module UnderArmour; class UnderArmourStoExportParser

  def self.parse s3_path
    self.new.parse s3_path
  end
  def parse s3_path
    @path = s3_path
    xlc = XLClient.new @path 
    @importer = Company.where(master:true).first
    @export_date = Date.strptime(xlc.get_cell(0,4,3).split(' ')[1],'%m/%d/%Y')
    @ref_1 = "#{@export_date.strftime("%Y%m%d")}-#{xlc.get_cell(0,7,3).split(' ').last}"
    last_row_num = xlc.last_row_number 0
    (21..last_row_num).each do |rn|
      row = xlc.get_row_as_column_hash 0, rn
      style_color_size = cv(row,0)
      next if style_color_size.blank?
      if style_color_size.match /\d{7} - /
        parse_row style_color_size, row, rn
      end
    end

  end
  def parse_row style_color_size, row, row_number
    coo = cv(row,1)
    part = "#{style_color_size}+#{coo}".gsub(' ','')
    d = DutyCalcExportFileLine.new(export_date:@export_date,ship_date:@export_date)
    d.part_number = part 
    d.carrier = 'Fedex Trade Network'
    d.ref_1 = @ref_1
    d.ref_2 = "#{@path.split('/').last}-#{row_number}"
    d.destination_country = 'CA'
    d.quantity = cv(row,2)
    d.schedule_b_code = cv(row,4) 
    d.description = cv(row,3)
    d.uom = "EA"
    d.exporter = "Under Armour"
    d.action_code = "E"
    d.importer = @importer
    d.save!
  end

  def cv row, position
    row[position]['value']
  end

end; end; end; end
