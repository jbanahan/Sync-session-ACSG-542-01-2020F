class LLSampleOrders
  def self.make_orders companies, orders_per_company
    p = make_sample_product
    ll_company = Company.where(master:true).first
    companies.each do |c|
      orders_per_company.times do
        make_order c, p, ll_company
      end
    end
  end

  def self.make_sample_product
    Product.where(unique_identifier:'SAMPLEPRODUCT').first_or_create(name:'Sample Product', importer:Company.where(master:true).first)
  end

  def self.make_order company, product, ll_company
    order_seq = 0
    loop do
      order_seq += 1
      ord = Order.where(vendor_id:company.id, order_number:"SAMPLE#{order_seq}").first
      break if ord.nil?
    end
    o = Order.new(
      order_number:"SAMPLE#{order_seq}",
      vendor_id: company.id,
      importer_id: ll_company.id,
      order_date: 0.seconds.ago,
      first_expected_delivery_date: 30.days.from_now,
      terms_of_payment: 'Due Immediately',
      terms_of_sale: 'FOB'
    )
    o.order_from_address = company.addresses.first
    ol = o.order_lines.build(
      line_number:1,
      product_id: product.id,
      quantity: 50,
      price_per_unit: 5,
      unit_of_measure: 'EA'
    )
    ol.ship_to = ll_company.addresses.where(name:'VIRGINIA WAREHOUSE').first

    o.save!

    return o
  end
end