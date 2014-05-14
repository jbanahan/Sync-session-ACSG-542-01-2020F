module OpenChain; module CustomHandler; module EddieBauer; class EddieBauerPoParser
  extend OpenChain::IntegrationClientParser

  def self.integration_folder
    "/opt/wftpserver/ftproot/www-vfitrack-net/_eddie_po"
  end

  def self.parse data, opts = {}
    self.new.process data
  end

  def initialize
    @eddie = Company.find_by_system_code 'EDDIE'
    raise "Can't find company with system code EDDIE." unless @eddie
    @ebcc = Company.find_by_system_code 'EBCC'
    raise "Can't find company with system code EBCC" unless @ebcc
  end

  def process data
    lines = []
    last_po = nil
    data.lines.each do |ln|
      raw_po = ln[0,14]
      if last_po && last_po != raw_po
        process_lines lines
        lines = []
      end
      last_po = raw_po
      lines << ln
    end
    if !lines.empty?
      process_lines lines
    end
  end

  private
  def process_lines lines
    Order.transaction do
      order = find_or_create_order lines.first
      order.order_lines.destroy_all
      lines.each_with_index do |ln,i|
        order.order_lines.build(
          line_number:i+1,
          product:find_or_create_product(ln),
          quantity:BigDecimal(ln[323,7])
        )
      end
      order.save!
    end
  end

  def find_or_create_product line
    Product.where(importer_id:@eddie.id,unique_identifier:"EDDIE-#{line[228,3]}-#{line[231,4]}").first_or_create!
  end

  def find_or_create_order line
    clean_order_number = line[0,14].sub('-','')
    importer = clean_order_number.ends_with?('0002') || clean_order_number.ends_with?('0004') ? @ebcc : @eddie
    ord = Order.where(importer_id:importer.id,order_number:"EDDIE-#{clean_order_number}").first_or_create!
    ord.customer_order_number = clean_order_number
    ord.vendor = Company.where(system_code:"EDDIE-#{line[301,8]}").first_or_create!(name:line[263,35].strip)
    return ord
  end
end; end; end; end