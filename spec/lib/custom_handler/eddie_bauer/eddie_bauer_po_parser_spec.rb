require 'spec_helper'

describe OpenChain::CustomHandler::EddieBauer::EddieBauerPoParser do
  before :each do
    @eddie = Factory(:company,system_code:'EDDIE')
    @ebcc = Factory(:company,system_code:'EBCC')
    @data = "E-0442532-0003                      MILLWORK PTE LTD                   91 E0002842            MILLWORK PTE (DIRECT)               0901            0067            201403302014033020140509OJAKARTA             N                   00670501                            PT METRO GARMIN FTY                91 E0002842-F007       ID0000800    M LS WR                                                                         SEATTLE DIRECT SOURCING  C
E-0442642-0011                      SHAHI EXPORTS PVT LTD              91 E0002450            SHAHI EXPORTS PVT LTD               0799            0009            201403282014032820140509OCHENNAI             N                   00098498                            SHAHI EXPORTS PVT LTD              91 E0002450-F001       IN0011134    W SS LACE                                                                       SEATTLE DIRECT SOURCING  X
E-0442642-0011                      SHAHI EXPORTS PVT LTD              91 E0002450            SHAHI EXPORTS PVT LTD               0799            0009            201403282014032820140509OCHENNAI             N                   00098499                            SHAHI EXPORTS PVT LTD              91 E0002450-F001       IN0002762    WP SS LCE                                                                       SEATTLE DIRECT SOURCING  X
E-0442642-0011                      SHAHI EXPORTS PVT LTD              91 E0002450            SHAHI EXPORTS PVT LTD               0799            0009            201403282014032820140509OCHENNAI             N                   00098500                            SHAHI EXPORTS PVT LTD              91 E0002450-F001       IN0002580    WT SS LACE                                                                      SEATTLE DIRECT SOURCING  X
E-0442642-0011                      SHAHI EXPORTS PVT LTD              91 E0002450            SHAHI EXPORTS PVT LTD               0799            0009            201403282014032820140509OCHENNAI             N                   00098501                            SHAHI EXPORTS PVT LTD              91 E0002450-F001       IN0002031    PLS SS LACE                                                                     SEATTLE DIRECT SOURCING  X"
  end
  it "should create orders" do
    expect { described_class.new.process(@data) }.to change(Order,:count).from(0).to(2)
    ord = Order.find_by_order_number('EDDIE-E0442642-0011')
    expect(ord.customer_order_number).to eq 'E0442642-0011'
    expect(ord.vendor.name).to eq 'SHAHI EXPORTS PVT LTD'
    expect(ord.vendor.system_code).to eq 'EDDIE-E0002450'
    expect(ord.importer).to eq @eddie
    expect(ord.order_lines.count).to eq 4
    ol = ord.order_lines.order(:line_number).first
    expect(ol.product.unique_identifier).to eq 'EDDIE-009-8498'
    expect(ol.quantity).to eq 11134
  end
  it "should create EBCC orders under EBCC" do
    # Use the two canada business codes as the two for the orders meaning that
    # both orders should be created under EBCC
    lines = @data.lines
    lines.each_with_index do |ln,i|
      ln.sub!('0003','0002')
      ln.sub!('0011','0004')
    end
    expect{described_class.new.process lines.join("")}.to change(Order.where(importer_id:@ebcc.id),:count).from(0).to(2)
  end
  it "should find existing product" do
    p = Factory(:product,unique_identifier:'EDDIE-009-8498',importer:@eddie)
    described_class.new.process(@data)
    expect(Order.find_by_order_number('EDDIE-E0442642-0011').order_lines.find_by_product_id(p.id)).not_to be_nil
  end
  it "should delete and rebuild lines on existing order" do
    p = Factory(:product,unique_identifier:'EDDIE-009-9999',importer:@eddie)
    line_to_delete = Factory(:order_line,product:p,order:Factory(:order,importer:@eddie,order_number:'EDDIE-E0442642-0011'))
    expect{described_class.new.process(@data)}.to change(OrderLine,:count).from(1).to(5)
    ord = line_to_delete.order
    ord.reload
    expect(ord.order_lines.count).to eq 4
    expect(ord.order_lines.find_by_product_id(p.id)).to be_nil
  end
  it "should use existing vendor" do
    sys_code = "EDDIE-E0002450"
    vendor = Factory(:company,vendor:true,system_code:sys_code)
    described_class.new.process @data
    expect(Order.find_by_order_number('EDDIE-E0442642-0011').vendor).to eq vendor
  end
end