require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberSapPirXmlParser do
  before :each do
    @data = '<?xml version="1.0" encoding="UTF-8" ?><INFREC01><IDOC BEGIN="1"><EDI_DC40 SEGMENT="1"><TABNAM>EDI_DC40</TABNAM><MANDT>100</MANDT><DOCNUM>0000000158084230</DOCNUM><DOCREL>740</DOCREL><STATUS>30</STATUS><DIRECT>1</DIRECT><OUTMOD>4</OUTMOD><IDOCTYP>INFREC01</IDOCTYP><MESTYP>/LUMBERL/VFI_INFREC</MESTYP><SNDPOR>SAPECP</SNDPOR><SNDPRT>LS</SNDPRT><SNDPRN>ECPCLNT100</SNDPRN><RCVPOR>PIPCLNT001</RCVPOR><RCVPRT>LS</RCVPRT><RCVPRN>VFI</RCVPRN><CREDAT>20160217</CREDAT><CRETIM>030448</CRETIM><SERIAL>20160217030448</SERIAL></EDI_DC40><E1EINAM SEGMENT="1"><MSGFN>005</MSGFN><INFNR>5300062517</INFNR><MATNR>000000000010039350</MATNR><LIFNR>0000202713</LIFNR><ERDAT>20150604</ERDAT><ERNAM>KYANCEY</ERNAM><MEINS>FOT</MEINS><UMREZ>1</UMREZ><UMREN>1</UMREN><MAHN1>0</MAHN1><MAHN2>0</MAHN2><MAHN3>0</MAHN3><URZDT>00000000</URZDT><URZLA>US</URZLA><LMEIN>FOT</LMEIN><REGIO>PA</REGIO><LTSSF>00000</LTSSF><LIFAB>00000000</LIFAB><LIFBI>00000000</LIFBI><ANZPU>0.000</ANZPU><RELIF>X</RELIF><E1EINEM SEGMENT="1"><MSGFN>005</MSGFN><EKORG>1000</EKORG><ESOKZ>0</ESOKZ><ERDAT>20150604</ERDAT><ERNAM>KYANCEY</ERNAM><EKGRP>105</EKGRP><WAERS>USD</WAERS><MINBM>0.000</MINBM><NORBM>1.000</NORBM><APLFZ>14</APLFZ><UEBTO>1.0</UEBTO><UNTTO>1.0</UNTTO><ANGDT>00000000</ANGDT><NETPR>2.46</NETPR><PEINH>1</PEINH><BPRME>FOT</BPRME><PRDAT>99991231</PRDAT><BPUMZ>1</BPUMZ><BPUMN>1</BPUMN><WEBRE>X</WEBRE><EFFPR>2.46</EFFPR><BSTAE>Z003</BSTAE><XERSN>X</XERSN><MHDRZ>0</MHDRZ><BSTMA>0.000</BSTMA><RDPRF>ZPD3</RDPRF><MEGRU>Z003</MEGRU><STAGING_TIME>  0</STAGING_TIME></E1EINEM></E1EINAM></IDOC></INFREC01>'
    @vendor_sap_number_cd = described_class.prep_custom_definitions([:cmp_sap_company])[:cmp_sap_company]
  end

  let (:opts) { {key: "path/to/file.xml", bucket: "bucket"}}
  let (:log) { InboundFile.new }

  it "should generate ProductVendorAssignment" do
    v = Factory(:company)
    v.update_custom_value!(@vendor_sap_number_cd,'0000202713')
    p = Factory(:product,unique_identifier:'000000000010039350')
    importer = Factory(:importer, system_code:'LUMBER')

    expect{described_class.parse_file(@data, log, opts)}.to change(ProductVendorAssignment,:count).from(0).to(1)

    pva = ProductVendorAssignment.first
    expect(pva.vendor).to eq v
    expect(pva.product).to eq p

    expect(pva.entity_snapshots.count).to eq 1
    expect(pva.entity_snapshots.first.context).to eq opts[:key]

    expect(log.company).to eq importer
    expect(log.isa_number).to eq "0000000158084230"
    expect(log.get_identifiers(InboundFileIdentifier::TYPE_ARTICLE_NUMBER)[0].value).to eq "000000000010039350"
    expect(log.get_identifiers(InboundFileIdentifier::TYPE_ARTICLE_NUMBER)[0].module_type).to eq "Product"
    expect(log.get_identifiers(InboundFileIdentifier::TYPE_ARTICLE_NUMBER)[0].module_id).to eq p.id
  end
  it "should do nothing if vendor doesn't exist" do
    Factory(:product,unique_identifier:'000000000010039350')

    expect{described_class.parse_file(@data, log, opts)}.to_not change(ProductVendorAssignment,:count)
  end
  it "should create product shell if product doesn't exist" do
    v = Factory(:company)
    v.update_custom_value!(@vendor_sap_number_cd,'0000202713')

    expect{described_class.parse_file(@data, log, opts)}.to change(ProductVendorAssignment,:count).from(0).to(1)

    pva = ProductVendorAssignment.first
    expect(pva.vendor).to eq v
    expect(pva.product.unique_identifier).to eq '000000000010039350'
  end
  it "should do nothing if ProductVendorAssignment already exists" do
    v = Factory(:company)
    v.update_custom_value!(@vendor_sap_number_cd,'0000202713')
    p = Factory(:product,unique_identifier:'000000000010039350')

    p.vendors << v

    expect{described_class.parse_file(@data, log, opts)}.to_not change(ProductVendorAssignment,:count)

    expect(EntitySnapshot.count).to eq 0
  end

  it "should fail if wrong root element provided" do
    data = "<WRONG_ROOT/>"
    expect{described_class.parse_file(data, log, opts)}.to raise_error "Incorrect root element WRONG_ROOT, expecting 'INFREC01'."
    expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_ERROR)[0].message).to eq "Incorrect root element WRONG_ROOT, expecting 'INFREC01'."
  end

  it "should fail if product UID missing" do
    data = @data.gsub '000000000010039350', ''
    expect{described_class.parse_file(data, log, opts)}.to raise_error "IDOC 0000000158084230 failed, no MATR value."
    expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_REJECT)[0].message).to eq "IDOC 0000000158084230 failed, no MATR value."
  end

  it "should fail if vendor SAP number missing" do
    data = @data.gsub '0000202713', ''
    expect{described_class.parse_file(data, log, opts)}.to raise_error "IDOC 0000000158084230 failed, no LIFNR value."
    expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_REJECT)[0].message).to eq "IDOC 0000000158084230 failed, no LIFNR value."
  end
end
