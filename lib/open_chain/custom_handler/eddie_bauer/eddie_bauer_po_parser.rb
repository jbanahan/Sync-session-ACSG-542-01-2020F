module OpenChain; module CustomHandler; module EddieBauer; class EddieBauerPoParser
  include OpenChain::IntegrationClientParser

  def self.integration_folder
    ["www-vfitrack-net/_eddie_po", "/home/ubuntu/ftproot/chainroot/www-vfitrack-net/_eddie_po"]
  end

  def self.parse data, opts = {}
    self.process data
  end

  def initialize
    @eddie = Company.find_by(system_code: 'EDDIE')
    raise "Can't find company with system code EDDIE." unless @eddie
    @ebcc = Company.find_by(system_code: 'EBCC')
    raise "Can't find company with system code EBCC." unless @ebcc
  end

  def self.process data
    lines = []
    last_po = nil
    data.lines.each do |ln|
      raw_po = ln[0,14]
      if last_po && last_po != raw_po
        self.delay.process_lines lines
        lines = []
      end
      last_po = raw_po
      lines << ln
    end
    if !lines.empty?
      self.delay.process_lines lines
    end
  end

  def self.process_lines lines
    self.new.process_lines lines
  end

  def process_lines lines
    products = find_or_create_products lines

    find_or_create_order(lines.first) do |order|
      order.order_lines.destroy_all
      lines.each_with_index do |ln,i|
        order.order_lines.build(
          line_number:i+1,
          product:products[product_style(ln)],
          quantity:BigDecimal(ln[323,7])
        )
      end
      order.save!
    end
  end

  private
  def find_or_create_products lines
    products = {}
    lines.each do |line|
      style = product_style(line)
      unique_identifier = "EDDIE-#{style}"

      Lock.acquire("Product-#{unique_identifier}") do
        products[style] = Product.where(importer_id:@eddie.id, unique_identifier:unique_identifier).first_or_create!
      end
    end

    products
  end

  def product_style line
    "#{line[228,3]}-#{line[231,4]}"
  end

  def find_or_create_order line
    order = nil
    clean_order_number = line[0,14].sub('-','')
    order_number = "EDDIE-#{clean_order_number}"

    Lock.acquire("Order-#{order_number}") do 
      importer = clean_order_number.ends_with?('0002') || clean_order_number.ends_with?('0004') ? @ebcc : @eddie
      order = Order.where(importer_id:importer.id,order_number:order_number).first_or_create!
      order.customer_order_number = clean_order_number
      order.vendor = Company.where(system_code:"EDDIE-#{line[301,8]}").first_or_create!(name:line[263,35].strip)
      yield order
    end

    order
  end
end; end; end; end