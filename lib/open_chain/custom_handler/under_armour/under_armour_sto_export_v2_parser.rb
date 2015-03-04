require 'open_chain/xl_client'

# Parse Under Armour Stock Transfer Invoices provided after 12/1/2014 for drawback export
module OpenChain; module CustomHandler; module UnderArmour; class UnderArmourStoExportV2Parser
  def self.parse s3_path
    DutyCalcExportFileLine.transaction do
      xlc = OpenChain::XLClient.new s3_path
      export_date = get_export_date xlc
      ref_num = get_ref_num xlc
      export_country_iso = get_export_country_iso xlc
      importer = Company.find_by_master(true)
      file_name = s3_path.split('/').last
      row = 4
      xlc.all_row_values(0,3) do |r|
        process_row r, export_date, ref_num, export_country_iso, importer, file_name, row
        row += 1
      end
    end
    nil
  end

  def self.process_row r, export_date, ref_num, export_country_iso, importer, file_name, row
    return if r[0].blank?
    raise "Body rows must be 4 columns: #{r}" unless r.size == 4
    raise "Column C must be a number: #{r}" unless r[2].to_s.match(/^\d*\.?\d*$/)
    d = DutyCalcExportFileLine.new
    d.importer = importer
    d.ship_date = export_date
    d.export_date = export_date
    d.carrier = 'FedEx'
    d.ref_1 = ref_num
    d.ref_2 = "#{file_name} - #{row}"
    d.destination_country = export_country_iso
    d.quantity = BigDecimal(r[2].to_s)
    d.description = r[3]
    d.uom = 'EA'
    d.exporter = 'Under Armour'
    d.action_code = 'E'
    d.importer = importer
    d.part_number = "#{r[0].gsub(' ','')}+#{r[1]}"
    d.save!
    d
  end
  private_class_method :process_row

  def self.get_export_date xlc
    export_date = xlc.get_cell(0,0,0)
    raise "Cell A1 must contain export date." if export_date.blank?
    return export_date if export_date.respond_to?(:acts_like_date?) || export_date.respond_to?(:strftime)
    date_parts = export_date.split('/')
    Date.new(date_parts[2].to_s.to_i,date_parts[0].to_s.to_i,date_parts[1].to_s.to_i)
  end
  private_class_method :get_export_date

  def self.get_ref_num xlc
    ref_num = xlc.get_cell(0,1,0)
    raise "Cell A2 must contain a shipment reference number." if ref_num.blank?
    ref_num.strip
  end
  private_class_method :get_ref_num

  def self.get_export_country_iso xlc
    iso = xlc.get_cell(0,2,0)
    raise "Cell A3 must contain a valid country of origin ISO code. \"#{iso}\" is not valid." if iso.blank? || Country.find_by_iso_code(iso).nil?
    iso
  end
  private_class_method :get_export_country_iso
end; end; end; end;
