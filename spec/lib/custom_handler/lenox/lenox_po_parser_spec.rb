require 'spec_helper'

describe OpenChain::CustomHandler::Lenox::LenoxPoParser do

  before :each do
    @testdata = "R                 RB05722520131105ABC                                                                                                                                                                             97 - MADELINE LUM            MADELINE_LUMA@LENOX.COM201402012014021520140215201403172014033120140331          56033                                               JAKARTA JAVA, INDONESIA              H01     HAGERSTOWN DISTRIBUTION CENTER           C/0 RECEIVING DEPARTMENT                                           16507 HUNTERS GREEN PARKWAY                                                                                               HAGERSTOWN                                 MD     21740 US                                                                                                                                                                                                                                                                                                                                                                                01                       IT               80-0326555               80-0326555                  6083927           BUTTERFLY MEADOW TEAPOT W/LID           1273USD              204      EACH              6             34          17200 LB           0575CBM          19563         584800OCN           BRANDS                  LENOX CORPORATION    ATTN:  IMPORT/EXPORT DEPARTMENT                                                 1414 RADCLIFFE STREET                                                                                                  BRISTOL                                 PA19007-5423 US          1160479                         PT HANKOOK                                                                                           JL RAYA CIKUPA         DESA SUKAHARJA PASAR KEMIS                                                     TANGERANG JAKARTA                                              ID                HANKOOK@LINK.NET.ID           000007                         PT HANKOOK                                                                                           JL RAYA CIKUPA         DESA SUKAHARJA PASAR KEMIS                                                     TANGERANG JAKARTA                                              ID                HANKOOK@LINK.NET.ID                                 ID  6911103750                                                                                                FOB
R                 RB05722520131105                                                                                                                                                                                97 - MADELINE LUM            MADELINE_LUMA@LENOX.COM201402012014021520140215201403172014033120140331          56033                                               JAKARTA JAVA, INDONESIA              H01     HAGERSTOWN DISTRIBUTION CENTER           C/0 RECEIVING DEPARTMENT                                           16507 HUNTERS GREEN PARKWAY                                                                                               HAGERSTOWN                                 MD     21740 US                                                                                                                                                                                                                                                                                                                                                                                02                       IT               80-0326555               80-0326555                  6083943        BUTTERFLY MEADOW COFFEEPOT W/LID           1377USD              120      EACH              6             20          16200 LB           0564CBM          11283         324000OCN           BRANDS                  LENOX CORPORATION    ATTN:  IMPORT/EXPORT DEPARTMENT                                                 1414 RADCLIFFE STREET                                                                                                  BRISTOL                                 PA19007-5423 US          1160479                         PT HANKOOK                                                                                           JL RAYA CIKUPA         DESA SUKAHARJA PASAR KEMIS                                                     TANGERANG JAKARTA                                              ID                HANKOOK@LINK.NET.ID           000007                         PT HANKOOK                                                                                           JL RAYA CIKUPA         DESA SUKAHARJA PASAR KEMIS                                                     TANGERANG JAKARTA                                              ID                HANKOOK@LINK.NET.ID                                 ID  6911103750                                                                                                FOB
R                 RB05722520131105                                                                                                                                                                                97 - MADELINE LUM            MADELINE_LUMA@LENOX.COM201402012014021520140215201403172014033120140331          56033                                               JAKARTA JAVA, INDONESIA              H01     HAGERSTOWN DISTRIBUTION CENTER           C/0 RECEIVING DEPARTMENT                                           16507 HUNTERS GREEN PARKWAY                                                                                               HAGERSTOWN                                 MD     21740 US                                                                                                                                                                                                                                                                                                                                                                                03                       IT               80-0326555               80-0326555                  6083984            BUTTERFLY MEADOW SUGAR W/LID            524USD              408      EACH             24             17          23016 LB           0541CBM           9190         391272OCN           BRANDS                  LENOX CORPORATION    ATTN:  IMPORT/EXPORT DEPARTMENT                                                 1414 RADCLIFFE STREET                                                                                                  BRISTOL                                 PA19007-5423 US          1160479                         PT HANKOOK                                                                                           JL RAYA CIKUPA         DESA SUKAHARJA PASAR KEMIS                                                     TANGERANG JAKARTA                                              ID                HANKOOK@LINK.NET.ID           000007                         PT HANKOOK                                                                                           JL RAYA CIKUPA         DESA SUKAHARJA PASAR KEMIS                                                     TANGERANG JAKARTA                                              ID                HANKOOK@LINK.NET.ID                                 ID  6911103750                                                                                                FOB
R                 RB05722520131105                                                                                                                                                                                97 - MADELINE LUM            MADELINE_LUMA@LENOX.COM201402012014021520140215201403172014033120140331          56033                                               JAKARTA JAVA, INDONESIA              H01     HAGERSTOWN DISTRIBUTION CENTER           C/0 RECEIVING DEPARTMENT                                           16507 HUNTERS GREEN PARKWAY                                                                                               HAGERSTOWN                                 MD     21740 US                                                                                                                                                                                                                                                                                                                                                                                04                       IT               80-0326555               80-0326555                  6101836             BUTTERFLY MEADOW FRUIT BOWL            133USD              432      EACH             24             18          16000 LB           0214CBM           3854         288000OCN           BRANDS                  LENOX CORPORATION    ATTN:  IMPORT/EXPORT DEPARTMENT                                                 1414 RADCLIFFE STREET                                                                                                  BRISTOL                                 PA19007-5423 US          1160479                         PT HANKOOK                                                                                           JL RAYA CIKUPA         DESA SUKAHARJA PASAR KEMIS                                                     TANGERANG JAKARTA                                              ID                HANKOOK@LINK.NET.ID           000007                         PT HANKOOK                                                                                           JL RAYA CIKUPA         DESA SUKAHARJA PASAR KEMIS                                                     TANGERANG JAKARTA                                              ID                HANKOOK@LINK.NET.ID                                 ID  6911103710                                                                                                FOB
R                 RB05722520131105                                                                                                                                                                                97 - MADELINE LUM            MADELINE_LUMA@LENOX.COM201402012014021520140215201403172014033120140331          56033                                               JAKARTA JAVA, INDONESIA              H01     HAGERSTOWN DISTRIBUTION CENTER           C/0 RECEIVING DEPARTMENT                                           16507 HUNTERS GREEN PARKWAY                                                                                               HAGERSTOWN                                 MD     21740 US                                                                                                                                                                                                                                                                                                                                                                                05                       IT               80-0326555               80-0326555                  6386635                BUTTERFLY MEADOW TEA SET           2498USD              248      EACH              4             62          31600 LB           0920CBM          57041        1959200OCN           BRANDS                  LENOX CORPORATION    ATTN:  IMPORT/EXPORT DEPARTMENT                                                 1414 RADCLIFFE STREET                                                                                                  BRISTOL                                 PA19007-5423 US          1160479                         PT HANKOOK                                                                                           JL RAYA CIKUPA         DESA SUKAHARJA PASAR KEMIS                                                     TANGERANG JAKARTA                                              ID                HANKOOK@LINK.NET.ID           000007                         PT HANKOOK                                                                                           JL RAYA CIKUPA         DESA SUKAHARJA PASAR KEMIS                                                     TANGERANG JAKARTA                                              ID                HANKOOK@LINK.NET.ID                                 ID  6911103710                                                                                                FOB
R                 RB05722520131105                                                                                                                                                                                97 - MADELINE LUM            MADELINE_LUMA@LENOX.COM201402012014021520140215201403172014033120140331          56033                                               JAKARTA JAVA, INDONESIA              H01     HAGERSTOWN DISTRIBUTION CENTER           C/0 RECEIVING DEPARTMENT                                           16507 HUNTERS GREEN PARKWAY                                                                                               HAGERSTOWN                                 MD     21740 US                                                                                                                                                                                                                                                                                                                                                                                06                       IT               80-0326555               80-0326555                  6444731      BUTTERFLY MEADOW DESSERT PLATE S/4            653USD              210      EACH              6             35          19000 LB           0203CBM           7111         665000OCN           BRANDS                  LENOX CORPORATION    ATTN:  IMPORT/EXPORT DEPARTMENT                                                 1414 RADCLIFFE STREET                                                                                                  BRISTOL                                 PA19007-5423 US          1160479                         PT HANKOOK                                                                                           JL RAYA CIKUPA         DESA SUKAHARJA PASAR KEMIS                                                     TANGERANG JAKARTA                                              ID                HANKOOK@LINK.NET.ID           000007                         PT HANKOOK                                                                                           JL RAYA CIKUPA         DESA SUKAHARJA PASAR KEMIS                                                     TANGERANG JAKARTA                                              ID                HANKOOK@LINK.NET.ID                                 ID  6911103750                                                                                                FOB
R                 RB05722520131105                                                                                                                                                                                97 - MADELINE LUM            MADELINE_LUMA@LENOX.COM201402012014021520140215201403172014033120140331          56033                                               JAKARTA JAVA, INDONESIA              H01     HAGERSTOWN DISTRIBUTION CENTER           C/0 RECEIVING DEPARTMENT                                           16507 HUNTERS GREEN PARKWAY                                                                                               HAGERSTOWN                                 MD     21740 US                                                                                                                                                                                                                                                                                                                                                                                07                       IT               80-0326555               80-0326555                   773903                BUTTERFLY MEADOW MUG S/4            707USD             1104      EACH              6            184          14330 LB           0338CBM          62192        2636720OCN           BRANDS                  LENOX CORPORATION    ATTN:  IMPORT/EXPORT DEPARTMENT                                                 1414 RADCLIFFE STREET                                                                                                  BRISTOL                                 PA19007-5423 US          1160479                         PT HANKOOK                                                                                           JL RAYA CIKUPA         DESA SUKAHARJA PASAR KEMIS                                                     TANGERANG JAKARTA                                              ID                HANKOOK@LINK.NET.ID           000007                         PT HANKOOK                                                                                           JL RAYA CIKUPA         DESA SUKAHARJA PASAR KEMIS                                                     TANGERANG JAKARTA                                              ID                HANKOOK@LINK.NET.ID                                 ID  6911103710                                                                                                FOB
R                 RB05722520131105                                                                                                                                                                                97 - MADELINE LUM            MADELINE_LUMA@LENOX.COM201402012014021520140215201403172014033120140331          56033                                               JAKARTA JAVA, INDONESIA              H01     HAGERSTOWN DISTRIBUTION CENTER           C/0 RECEIVING DEPARTMENT                                           16507 HUNTERS GREEN PARKWAY                                                                                               HAGERSTOWN                                 MD     21740 US                                                                                                                                                                                                                                                                                                                                                                                08                       IT               80-0326555               80-0326555                  6444731      BUTTERFLY MEADOW DESSERT PLATE S/4            653USD              564      EACH              6             94          19000 LB           0203CBM          19097        1786000OCN           BRANDS                  LENOX CORPORATION    ATTN:  IMPORT/EXPORT DEPARTMENT                                                 1414 RADCLIFFE STREET                                                                                                  BRISTOL                                 PA19007-5423 US          1160479                         PT HANKOOK                                                                                           JL RAYA CIKUPA         DESA SUKAHARJA PASAR KEMIS                                                     TANGERANG JAKARTA                                              ID                HANKOOK@LINK.NET.ID           000007                         PT HANKOOK                                                                                           JL RAYA CIKUPA         DESA SUKAHARJA PASAR KEMIS                                                     TANGERANG JAKARTA                                              ID                HANKOOK@LINK.NET.ID                                 ID  6911103750                                                                                                FOB
R                 RB05722520131105                                                                                                                                                                                97 - MADELINE LUM            MADELINE_LUMA@LENOX.COM201402012014021520140215201403172014033120140331          56033                                               JAKARTA JAVA, INDONESIA              H01     HAGERSTOWN DISTRIBUTION CENTER           C/0 RECEIVING DEPARTMENT                                           16507 HUNTERS GREEN PARKWAY                                                                                               HAGERSTOWN                                 MD     21740 US                                                                                                                                                                                                                                                                                                                                                                                09                       IT               80-0326555               80-0326555                  6101836             BUTTERFLY MEADOW FRUIT BOWL            133USD             2568      EACH             24            107          16000 LB           0214CBM          22908        1712000OCN           BRANDS                  LENOX CORPORATION    ATTN:  IMPORT/EXPORT DEPARTMENT                                                 1414 RADCLIFFE STREET                                                                                                  BRISTOL                                 PA19007-5423 US          1160479                         PT HANKOOK                                                                                           JL RAYA CIKUPA         DESA SUKAHARJA PASAR KEMIS                                                     TANGERANG JAKARTA                                              ID                HANKOOK@LINK.NET.ID           000007                         PT HANKOOK                                                                                           JL RAYA CIKUPA         DESA SUKAHARJA PASAR KEMIS                                                     TANGERANG JAKARTA                                              ID                HANKOOK@LINK.NET.ID                                 ID  6911103710                                                                                                FOB
R                 RB05722520131105                                                                                                                                                                                97 - MADELINE LUM            MADELINE_LUMA@LENOX.COM201402012014021520140215201403172014033120140331          56033                                               JAKARTA JAVA, INDONESIA              H01     HAGERSTOWN DISTRIBUTION CENTER           C/0 RECEIVING DEPARTMENT                                           16507 HUNTERS GREEN PARKWAY                                                                                               HAGERSTOWN                                 MD     21740 US                                                                                                                                                                                                                                                                                                                                                                                10                       IT               80-0326555               80-0326555                  6444731      BUTTERFLY MEADOW DESSERT PLATE S/4            653USD               42      EACH              6              7          19000 LB           0203CBM           1422         133000OCN           BRANDS                  LENOX CORPORATION    ATTN:  IMPORT/EXPORT DEPARTMENT                                                 1414 RADCLIFFE STREET                                                                                                  BRISTOL                                 PA19007-5423 US          1160479                         PT HANKOOK                                                                                           JL RAYA CIKUPA         DESA SUKAHARJA PASAR KEMIS                                                     TANGERANG JAKARTA                                              ID                HANKOOK@LINK.NET.ID           000007                         PT HANKOOK                                                                                           JL RAYA CIKUPA         DESA SUKAHARJA PASAR KEMIS                                                     TANGERANG JAKARTA                                              ID                HANKOOK@LINK.NET.ID                                 ID  6911103750                                                                                                FOB
R                 RB05722520131105                                                                                                                                                                                97 - MADELINE LUM            MADELINE_LUMA@LENOX.COM201402012014021520140215201403172014033120140331          56033                                               JAKARTA JAVA, INDONESIA              H01     HAGERSTOWN DISTRIBUTION CENTER           C/0 RECEIVING DEPARTMENT                                           16507 HUNTERS GREEN PARKWAY                                                                                               HAGERSTOWN                                 MD     21740 US                                                                                                                                                                                                                                                                                                                                                                                11                       IT               80-0326555               80-0326555                  6083943        BUTTERFLY MEADOW COFFEEPOT W/LID           1377USD               30      EACH              6              5          16200 LB           0564CBM           2821          81000OCN           BRANDS                  LENOX CORPORATION    ATTN:  IMPORT/EXPORT DEPARTMENT                                                 1414 RADCLIFFE STREET                                                                                                  BRISTOL                                 PA19007-5423 US          1160479                         PT HANKOOK                                                                                           JL RAYA CIKUPA         DESA SUKAHARJA PASAR KEMIS                                                     TANGERANG JAKARTA                                              ID                HANKOOK@LINK.NET.ID           000007                         PT HANKOOK                                                                                           JL RAYA CIKUPA         DESA SUKAHARJA PASAR KEMIS                                                     TANGERANG JAKARTA                                              ID                HANKOOK@LINK.NET.ID                                 ID  6911103750                                                                                                FOB
R                 RB05722520131105                                                                                                                                                                                97 - MADELINE LUM            MADELINE_LUMA@LENOX.COM201402012014021520140215201403172014033120140331          56033                                               JAKARTA JAVA, INDONESIA              H01     HAGERSTOWN DISTRIBUTION CENTER           C/0 RECEIVING DEPARTMENT                                           16507 HUNTERS GREEN PARKWAY                                                                                               HAGERSTOWN                                 MD     21740 US                                                                                                                                                                                                                                                                                                                                                                                12                       AC               80-0326555               80-0326555                  6386635                BUTTERFLY MEADOW TEA SET           2498USD              252      EACH              4             63          31600 LB           0920CBM          57961        1990800OCN           BRANDS                  LENOX CORPORATION    ATTN:  IMPORT/EXPORT DEPARTMENT                                                 1414 RADCLIFFE STREET                                                                                                  BRISTOL                                 PA19007-5423 US          1160479                         PT HANKOOK                                                                                           JL RAYA CIKUPA         DESA SUKAHARJA PASAR KEMIS                                                     TANGERANG JAKARTA                                              ID                HANKOOK@LINK.NET.ID           000007                         PT HANKOOK                                                                                           JL RAYA CIKUPA         DESA SUKAHARJA PASAR KEMIS                                                     TANGERANG JAKARTA                                              ID                HANKOOK@LINK.NET.ID                                 ID  6911103710                                                                                                FOB"
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
    expect(o.order_lines.count).to eq 12 
    expect(o.order_lines.collect {|ol| ol.product.unique_identifier}.sort.uniq).to eq [
'LENOX-6083927',
'LENOX-6083943',
'LENOX-6083984',
'LENOX-6101836',
'LENOX-6386635',
'LENOX-6444731',
'LENOX-773903'
    ]
    ln = o.order_lines.first
    expect(ln.line_number).to eq 1
    expect(ln.price_per_unit).to eq BigDecimal("12.73")
    expect(ln.quantity).to eq 204 
    expect(ln.currency).to eq 'USD'
    expect(ln.get_custom_value(c_defs[:order_line_note]).value).to eq 'ABC'
    expect(ln.country_of_origin).to eq 'ID'
    expect(ln.hts).to eq '6911103750'

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
  it "should update existing PO, updating but not deleting lines" do
    ord = Factory(:order,order_number:'LENOX-RB057225',importer_id:@lenox.id)
    o_line = Factory(:order_line,order:ord,line_number:1) #update this one
    o_line2 = Factory(:order_line,order:ord,line_number:100) #leave this one alone
    described_class.new.process @testdata
    expect(Order.count).to eq 1
    o = Order.first
    expect(o.order_number).to eq 'LENOX-RB057225'
    expect(o.order_lines.count).to eq 13
    expect(o.id).to eq ord.id
    expect(o.order_lines.find_by_line_number(1).product.unique_identifier).to eq 'LENOX-6083927'
    expect(o.order_lines.find_by_line_number(100)).to eq o_line2
  end
  it "should delete orders with D as first character" do
    ord = Factory(:order,order_number:'LENOX-RB057225',importer_id:@lenox.id)
    td = ""
    @testdata.lines.each {|ln| ln[0] = 'D'; td << ln}
    described_class.new.process td
    expect(Order.all).to be_empty
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
      expect(described_class.integration_folder).to eq "/opt/wftpserver/ftproot/www-vfitrack-net/_lenox_po"
    end
  end
end
