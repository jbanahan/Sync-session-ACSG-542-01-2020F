require 'spec_helper'

describe OpenChain::CustomHandler::Lenox::LenoxPoParser do

  before :each do
    @testdata = "R                 RB05722520131105ABC                                                                                                                                                                             97 - MADELINE LUM            MADELINE_LUMA@LENOX.COM201402012014021520140215201403172014033120140331          56033                                               JAKARTA JAVA, INDONESIA              H01     HAGERSTOWN DISTRIBUTION CENTER           C/0 RECEIVING DEPARTMENT                                           16507 HUNTERS GREEN PARKWAY                                                                                               HAGERSTOWN                                 MD     21740 US                                                                                                                                                                                                                                                                                                                                                                                01                       IT               80-0326555               80-0326555                  6083927           BUTTERFLY MEADOW TEAPOT W/LID           1273USD              204      EACH              6             34          17200 LB           0575CBM          19563         584800OCN           BRANDS                  LENOX CORPORATION    ATTN:  IMPORT/EXPORT DEPARTMENT                                                 1414 RADCLIFFE STREET                                                                                                  BRISTOL                                 PA19007-5423 US          1160479                         PT HANKOOK                                                                                           JL RAYA CIKUPA         DESA SUKAHARJA PASAR KEMIS                                                     TANGERANG JAKARTA                                              ID                HANKOOK@LINK.NET.ID           000007                         PT HANKOOK                                                                                           JL RAYA CIKUPA         DESA SUKAHARJA PASAR KEMIS                                                     TANGERANG JAKARTA                                              ID                HANKOOK@LINK.NET.ID                                 ID  6911103750                                                                                                FOB              HDC
R                 RB05722520131105                                                                                                                                                                                97 - MADELINE LUM            MADELINE_LUMA@LENOX.COM201402012014021520140215201403172014033120140331          56033                                               JAKARTA JAVA, INDONESIA              H01     HAGERSTOWN DISTRIBUTION CENTER           C/0 RECEIVING DEPARTMENT                                           16507 HUNTERS GREEN PARKWAY                                                                                               HAGERSTOWN                                 MD     21740 US                                                                                                                                                                                                                                                                                                                                                                                02                       IT               80-0326555               80-0326555                  6083943        BUTTERFLY MEADOW COFFEEPOT W/LID           1377USD              120      EACH              6             20          16200 LB           0564CBM          11283         324000OCN           BRANDS                  LENOX CORPORATION    ATTN:  IMPORT/EXPORT DEPARTMENT                                                 1414 RADCLIFFE STREET                                                                                                  BRISTOL                                 PA19007-5423 US          1160479                         PT HANKOOK                                                                                           JL RAYA CIKUPA         DESA SUKAHARJA PASAR KEMIS                                                     TANGERANG JAKARTA                                              ID                HANKOOK@LINK.NET.ID           000007                         PT HANKOOK                                                                                           JL RAYA CIKUPA         DESA SUKAHARJA PASAR KEMIS                                                     TANGERANG JAKARTA                                              ID                HANKOOK@LINK.NET.ID                                 ID  6911103750                                                                                                FOB              HDC
R                 RB05722520131105                                                                                                                                                                                97 - MADELINE LUM            MADELINE_LUMA@LENOX.COM201402012014021520140215201403172014033120140331          56033                                               JAKARTA JAVA, INDONESIA              H01     HAGERSTOWN DISTRIBUTION CENTER           C/0 RECEIVING DEPARTMENT                                           16507 HUNTERS GREEN PARKWAY                                                                                               HAGERSTOWN                                 MD     21740 US                                                                                                                                                                                                                                                                                                                                                                                03                       IT               80-0326555               80-0326555                  6083984            BUTTERFLY MEADOW SUGAR W/LID            524USD              408      EACH             24             17          23016 LB           0541CBM           9190         391272OCN           BRANDS                  LENOX CORPORATION    ATTN:  IMPORT/EXPORT DEPARTMENT                                                 1414 RADCLIFFE STREET                                                                                                  BRISTOL                                 PA19007-5423 US          1160479                         PT HANKOOK                                                                                           JL RAYA CIKUPA         DESA SUKAHARJA PASAR KEMIS                                                     TANGERANG JAKARTA                                              ID                HANKOOK@LINK.NET.ID           000007                         PT HANKOOK                                                                                           JL RAYA CIKUPA         DESA SUKAHARJA PASAR KEMIS                                                     TANGERANG JAKARTA                                              ID                HANKOOK@LINK.NET.ID                                 ID  6911103750                                                                                                FOB              HDC"
    @lenox = Factory(:company,system_code:'LENOX')
  end
  
  it "should create PO" do
    described_class.new.process @testdata
    c_defs = described_class.prep_custom_definitions described_class::CUSTOM_DEFINITION_INSTRUCTIONS.keys
    expect(Order.count).to eq 1
    o = Order.first
    expect(o.order_number).to eq 'LENOX-RB057225'
    expect(o.customer_order_number).to eq 'RB057225'
    expect(o.order_date).to eq Date.new(2013,11,5)
    expect(o.mode).to eq 'OCN'
    expect(o.get_custom_value(c_defs[:order_buyer_name]).value).to eq '97 - MADELINE LUM'
    expect(o.get_custom_value(c_defs[:order_buyer_email]).value).to eq 'MADELINE_LUMA@LENOX.COM'
    expect(o.get_custom_value(c_defs[:order_destination_code]).value).to eq 'H01'
    expect(o.get_custom_value(c_defs[:order_factory_code]).value).to eq '000007'
    expect(o.importer).to eq @lenox
    expect(o.order_lines.count).to eq 3
    expect(o.order_lines.collect {|ol| ol.product.unique_identifier}.sort.uniq).to eq [
'LENOX-6083927',
'LENOX-6083943',
'LENOX-6083984',
    ]
    ln = o.order_lines.first
    expect(ln.line_number).to eq 1
    expect(ln.price_per_unit).to eq BigDecimal("12.73")
    expect(ln.quantity).to eq 204 
    expect(ln.currency).to eq 'USD'
    expect(ln.get_custom_value(c_defs[:order_line_note]).value).to eq 'ABC'
    expect(ln.country_of_origin).to eq 'ID'
    expect(ln.hts).to eq '6911103750'
    expect(ln.get_custom_value(c_defs[:order_line_destination_code]).value).to eq 'HDC'

    #test product construction
    p = ln.product
    expect(p.get_custom_value(c_defs[:part_number]).value).to eq '6083927' 
    expect(p.name).to eq 'BUTTERFLY MEADOW TEAPOT W/LID'
    expect(p.importer).to eq @lenox

    #test vendor construction
    vn = o.vendor
    expect(vn.system_code).to eq 'LENOX-1160479'
    expect(vn.name).to eq 'PT HANKOOK'
    @lenox.reload
    expect(@lenox.linked_companies.first).to eq vn


  end
  it "should move existing product to correct importer" do
    p = Factory(:product, unique_identifier:'LENOX-6083927')
    described_class.new.process @testdata
    pr = Order.first.order_lines.first.product
    expect(pr.id).to eq p.id
    expect(pr.importer).to eq @lenox
  end
  it "should update existing PO, updating but not deleting lines" do
    ord = Factory(:order,order_number:'LENOX-RB057225',importer_id:@lenox.id)
    o_line = Factory(:order_line,order:ord,line_number:1) #update this one
    o_line2 = Factory(:order_line,order:ord,line_number:100) #leave this one alone
    described_class.new.process @testdata
    expect(Order.count).to eq 1
    o = Order.first
    expect(o.order_number).to eq 'LENOX-RB057225'
    expect(o.order_lines.count).to eq 4
    expect(o.id).to eq ord.id
    expect(o.order_lines.find_by_line_number(1).product.unique_identifier).to eq 'LENOX-6083927'
    expect(o.order_lines.find_by_line_number(100)).to eq o_line2
  end
  it "should delete lines with D as first character" do
    ord = Factory(:order,order_number:'LENOX-RB057225',importer_id:@lenox.id)
    o_line = Factory(:order_line,order:ord,line_number:1) #delete this one
    o_line2 = Factory(:order_line,order:ord,line_number:100) #leave this one alone
    @testdata[0] = 'D'
    described_class.new.process @testdata
    ord.reload
    expect(ord.order_lines.collect {|ol| ol.line_number}.sort).to eq [2,3,100]
  end
  it "should delete order with no lines" do
    ord = Factory(:order,order_number:'LENOX-RB057225',importer_id:@lenox.id)
    o_line = Factory(:order_line,order:ord,line_number:1) #delete this one
    td = ""
    @testdata.lines.each {|ln| ln[0] = 'D'; td << ln}
    described_class.new.process td
    expect(Order.count).to eq 0
  end
  it "should update earliest ship date on product if earlier than existing date" do
    p = Factory(:product,unique_identifier:'LENOX-6083927',importer:@lenox)
    cd = described_class.prep_custom_definitions([:product_earliest_ship]).values.first
    p.update_custom_value!(cd,Date.new(2015,1,1))
    described_class.new.process @testdata
    expect(Product.find(p.id).get_custom_value(cd).value).to eq Date.new(2014,2,1)
  end
  it "should not update earliest ship date on product if later than existing date" do
    p = Factory(:product,unique_identifier:'LENOX-6083927',importer:@lenox)
    cd = described_class.prep_custom_definitions([:product_earliest_ship]).values.first
    p.update_custom_value!(cd,Date.new(2013,1,1))
    described_class.new.process @testdata
    expect(Product.find(p.id).get_custom_value(cd).value).to eq Date.new(2013,1,1)
  end

  describe "parse" do
    it "creates a PO" do
      # This method is just an integration point that call through to the process method..all we're testing is that
      # an order is created
      described_class.parse @testdata

      expect(Order.first.order_number).to eq 'LENOX-RB057225'
    end
  end

  describe "integration_folder" do
    it "uses an integration folder" do
      expect(described_class.integration_folder).to eq ["//opt/wftpserver/ftproot/www-vfitrack-net/_lenox_po", "/home/ubuntu/ftproot/chainroot/www-vfitrack-net/_lenox_po"]
    end
  end
end
