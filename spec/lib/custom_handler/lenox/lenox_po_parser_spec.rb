describe OpenChain::CustomHandler::Lenox::LenoxPoParser do

  let!(:testdata) do
    <<~HEREDOC
      R                 RB05722520131105ABC                                                                                                                                                                             97 - MADELINE LUM            MADELINE_LUMA@LENOX.COM201402012014021520140215201403172014033120140331          56033                                               JAKARTA JAVA, INDONESIA              H01     HAGERSTOWN DISTRIBUTION CENTER           C/0 RECEIVING DEPARTMENT                                           16507 HUNTERS GREEN PARKWAY                                                                                               HAGERSTOWN                                 MD     21740 US                                                                                                                                                                                                                                                                                                                                                                                01                       IT               80-0326555               80-0326555                  6083927           BUTTERFLY MEADOW TEAPOT W/LID           1273USD              204      EACH              6             34          17200 LB           0575CBM          19563         584800OCN           BRANDS                  LENOX CORPORATION    ATTN:  IMPORT/EXPORT DEPARTMENT                                                 1414 RADCLIFFE STREET                                                                                                  BRISTOL                                 PA19007-5423 US          1160479                         PT HANKOOK                                                                                           JL RAYA CIKUPA         DESA SUKAHARJA PASAR KEMIS                                                     TANGERANG JAKARTA                                              ID                HANKOOK@LINK.NET.ID           000007                         PT HANKOOK                                                                                           JL RAYA CIKUPA         DESA SUKAHARJA PASAR KEMIS                                                     TANGERANG JAKARTA                                              ID                HANKOOK@LINK.NET.ID                                 ID  6911103750                                                                                                FOB              HDC
      R                 RB05722520131105                                                                                                                                                                                97 - MADELINE LUM            MADELINE_LUMA@LENOX.COM201402012014021520140215201403172014033120140331          56033                                               JAKARTA JAVA, INDONESIA              H01     HAGERSTOWN DISTRIBUTION CENTER           C/0 RECEIVING DEPARTMENT                                           16507 HUNTERS GREEN PARKWAY                                                                                               HAGERSTOWN                                 MD     21740 US                                                                                                                                                                                                                                                                                                                                                                                02                       IT               80-0326555               80-0326555                  6083943        BUTTERFLY MEADOW COFFEEPOT W/LID           1377USD              120      EACH              6             20          16200 LB           0564CBM          11283         324000OCN           BRANDS                  LENOX CORPORATION    ATTN:  IMPORT/EXPORT DEPARTMENT                                                 1414 RADCLIFFE STREET                                                                                                  BRISTOL                                 PA19007-5423 US          1160479                         PT HANKOOK                                                                                           JL RAYA CIKUPA         DESA SUKAHARJA PASAR KEMIS                                                     TANGERANG JAKARTA                                              ID                HANKOOK@LINK.NET.ID           000007                         PT HANKOOK                                                                                           JL RAYA CIKUPA         DESA SUKAHARJA PASAR KEMIS                                                     TANGERANG JAKARTA                                              ID                HANKOOK@LINK.NET.ID                                 ID  6911103750                                                                                                FOB              HDC
      R                 RB05722520131105                                                                                                                                                                                97 - MADELINE LUM            MADELINE_LUMA@LENOX.COM201402012014021520140215201403172014033120140331          56033                                               JAKARTA JAVA, INDONESIA              H01     HAGERSTOWN DISTRIBUTION CENTER           C/0 RECEIVING DEPARTMENT                                           16507 HUNTERS GREEN PARKWAY                                                                                               HAGERSTOWN                                 MD     21740 US                                                                                                                                                                                                                                                                                                                                                                                03                       IT               80-0326555               80-0326555                  6083984            BUTTERFLY MEADOW SUGAR W/LID            524USD              408      EACH             24             17          23016 LB           0541CBM           9190         391272OCN           BRANDS                  LENOX CORPORATION    ATTN:  IMPORT/EXPORT DEPARTMENT                                                 1414 RADCLIFFE STREET                                                                                                  BRISTOL                                 PA19007-5423 US          1160479                         PT HANKOOK                                                                                           JL RAYA CIKUPA         DESA SUKAHARJA PASAR KEMIS                                                     TANGERANG JAKARTA                                              ID                HANKOOK@LINK.NET.ID           000007                         PT HANKOOK                                                                                           JL RAYA CIKUPA         DESA SUKAHARJA PASAR KEMIS                                                     TANGERANG JAKARTA                                              ID                HANKOOK@LINK.NET.ID                                 ID  6911103750                                                                                                FOB              HDC
    HEREDOC
  end

  let!(:lenox) { Factory(:company, system_code: 'LENOX') }

  let (:log) { InboundFile.new }

  it "creates PO" do
    described_class.new.process testdata, log
    c_defs = described_class.prep_custom_definitions [:ord_buyer, :ord_buyer_email, :ord_destination_code, :ord_factory_code, :ord_line_note,
                                                      :ord_line_destination_code, :prod_part_number, :prod_earliest_ship_date]
    expect(Order.count).to eq 1
    o = Order.first
    expect(o.order_number).to eq 'LENOX-RB057225'
    expect(o.customer_order_number).to eq 'RB057225'
    expect(o.order_date).to eq Date.new(2013, 11, 5)
    expect(o.mode).to eq 'OCN'
    expect(o.get_custom_value(c_defs[:ord_buyer]).value).to eq '97 - MADELINE LUM'
    expect(o.get_custom_value(c_defs[:ord_buyer_email]).value).to eq 'MADELINE_LUMA@LENOX.COM'
    expect(o.get_custom_value(c_defs[:ord_destination_code]).value).to eq 'H01'
    expect(o.get_custom_value(c_defs[:ord_factory_code]).value).to eq '000007'
    expect(o.importer).to eq lenox
    expect(o.order_lines.count).to eq 3
    expect(o.order_lines.collect { |ol| ol.product.unique_identifier }.sort.uniq).to eq ['LENOX-6083927', 'LENOX-6083943', 'LENOX-6083984']
    ln = o.order_lines.first
    expect(ln.line_number).to eq 1
    expect(ln.price_per_unit).to eq BigDecimal("12.73")
    expect(ln.quantity).to eq 204
    expect(ln.currency).to eq 'USD'
    expect(ln.get_custom_value(c_defs[:ord_line_note]).value).to eq 'ABC'
    expect(ln.country_of_origin).to eq 'ID'
    expect(ln.hts).to eq '6911103750'
    expect(ln.get_custom_value(c_defs[:ord_line_destination_code]).value).to eq 'HDC'

    # test product construction
    p = ln.product
    expect(p.get_custom_value(c_defs[:prod_part_number]).value).to eq '6083927'
    expect(p.name).to eq 'BUTTERFLY MEADOW TEAPOT W/LID'
    expect(p.importer).to eq lenox

    # test vendor construction
    vn = o.vendor
    expect(vn.system_code).to eq 'LENOX-1160479'
    expect(vn.name).to eq 'PT HANKOOK'
    lenox.reload
    expect(lenox.linked_companies.first).to eq vn

    expect(log.company).to eq lenox
    expect(log.get_identifiers(InboundFileIdentifier::TYPE_PO_NUMBER)[0].value).to eq "RB057225"
    expect(log.get_identifiers(InboundFileIdentifier::TYPE_PO_NUMBER)[0].module_type).to eq "Order"
    expect(log.get_identifiers(InboundFileIdentifier::TYPE_PO_NUMBER)[0].module_id).to eq o.id
  end

  it "moves existing product to correct importer" do
    p = Factory(:product, unique_identifier: 'LENOX-6083927')
    described_class.new.process testdata, log
    pr = Order.first.order_lines.first.product
    expect(pr.id).to eq p.id
    expect(pr.importer).to eq lenox
  end

  it "updates existing PO, updating but not deleting lines" do
    ord = Factory(:order, order_number: 'LENOX-RB057225', importer_id: lenox.id)
    Factory(:order_line, order: ord, line_number: 1) # update this one
    o_line2 = Factory(:order_line, order: ord, line_number: 100) # leave this one alone
    described_class.new.process testdata, log
    expect(Order.count).to eq 1
    o = Order.first
    expect(o.order_number).to eq 'LENOX-RB057225'
    expect(o.order_lines.count).to eq 4
    expect(o.id).to eq ord.id
    expect(o.order_lines.find_by(line_number: 1).product.unique_identifier).to eq 'LENOX-6083927'
    expect(o.order_lines.find_by(line_number: 100)).to eq o_line2
  end

  it "deletes lines with D as first character" do
    ord = Factory(:order, order_number: 'LENOX-RB057225', importer_id: lenox.id)
    Factory(:order_line, order: ord, line_number: 1) # delete this one
    Factory(:order_line, order: ord, line_number: 100) # leave this one alone
    testdata[0] = 'D'
    described_class.new.process testdata, log
    ord.reload
    expect(ord.order_lines.collect(&:line_number).sort).to eq [2, 3, 100]
  end

  it "doesn't delete shipped lines" do
    ord = Factory(:order, order_number: 'LENOX-RB057225', importer_id: lenox.id)

    prod = Factory(:product)
    o_line = Factory(:order_line, order: ord, line_number: 1, product: prod)
    s_line = Factory(:shipment_line, product: prod)
    PieceSet.create! order_line: o_line, shipment_line: s_line, quantity: 1
    testdata[0] = 'D'

    described_class.new.process testdata, log
    ord.reload
    expect(ord.order_lines.collect(&:line_number).sort).to eq [1, 2, 3]
  end

  it "deletes order with no lines" do
    ord = Factory(:order, order_number: 'LENOX-RB057225', importer_id: lenox.id)
    Factory(:order_line, order: ord, line_number: 1) # delete this one
    td = ""
    testdata.lines.each {|ln| ln[0] = 'D'; td << ln}
    described_class.new.process td, log
    expect(Order.count).to eq 0
  end

  it "updates earliest ship date on product if earlier than existing date" do
    p = Factory(:product, unique_identifier: 'LENOX-6083927', importer: lenox)
    cd = described_class.prep_custom_definitions([:prod_earliest_ship_date]).values.first
    p.update_custom_value!(cd, Date.new(2015, 1, 1))
    described_class.new.process testdata, log
    expect(Product.find(p.id).get_custom_value(cd).value).to eq Date.new(2014, 2, 1)
  end

  it "doesn't update earliest ship date on product if later than existing date" do
    p = Factory(:product, unique_identifier: 'LENOX-6083927', importer: lenox)
    cd = described_class.prep_custom_definitions([:prod_earliest_ship_date]).values.first
    p.update_custom_value!(cd, Date.new(2013, 1, 1))
    described_class.new.process testdata, log
    expect(Product.find(p.id).get_custom_value(cd).value).to eq Date.new(2013, 1, 1)
  end

  describe "parse_file" do
    it "creates a PO" do
      # This method is just an integration point that call through to the process method..all we're testing is that
      # an order is created
      described_class.parse_file testdata, log

      expect(Order.first.order_number).to eq 'LENOX-RB057225'
    end
  end

  describe "integration_folder" do
    it "uses an integration folder" do
      expect(described_class.integration_folder).to eq ["www-vfitrack-net/_lenox_po", "/home/ubuntu/ftproot/chainroot/www-vfitrack-net/_lenox_po"]
    end
  end
end
