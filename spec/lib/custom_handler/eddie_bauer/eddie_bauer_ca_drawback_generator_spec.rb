require "spec_helper"

describe OpenChain::CustomHandler::EddieBauer::EddieBauerCaDrawbackGenerator do
  describe "generate_exports_from_us_entry" do
    it "should make DutyCalcExportFileLines" do
      ent = Factory(:entry,importer:Factory(:importer,name:'EBC'),entry_number:'123456',arrival_date:Date.new(2014,1,10),export_date:Date.new(2013,12,24),carrier_name:'FEDEX',master_bills_of_lading:'MBOL')
      ci = Factory(:commercial_invoice,invoice_number:'INVNUM',entry:ent)
      cil1 = Factory(:commercial_invoice_line,commercial_invoice:ci,quantity:50,part_number:'pn1',unit_of_measure:'uom1')
      ct1 = Factory(:commercial_invoice_tariff,commercial_invoice_line:cil1,hts_code:'1234567890',tariff_description:'td1')
      cil2 = Factory(:commercial_invoice_line,commercial_invoice:ci,quantity:23,part_number:'pn2',unit_of_measure:'uom2')
      ct2 = Factory(:commercial_invoice_tariff,commercial_invoice_line:cil2,hts_code:'0987654321',tariff_description:'td2')
      expect { described_class.new.generate_exports_from_us_entry(ent) }.to change(DutyCalcExportFileLine,:count).from(0).to(2)

      ln1 = DutyCalcExportFileLine.first
      expect(ln1.importer).to eql(ent.importer)
      expect(ln1.export_date).to eql(ent.export_date)
      expect(ln1.ship_date).to eql(ent.export_date)
      expect(ln1.part_number).to eql('pn1')
      expect(ln1.carrier).to eql('FEDEX')
      expect(ln1.ref_1).to eql(ent.entry_number)
      expect(ln1.ref_2).to eql(ent.master_bills_of_lading)
      expect(ln1.ref_3).to eql(cil1.id.to_s)
      expect(ln1.destination_country).to eql('US')
      expect(ln1.quantity.to_i).to eql(cil1.quantity.to_i)
      expect(ln1.hts_code).to eql(ct1.hts_code)
      expect(ln1.description).to eql(ct1.tariff_description)
      expect(ln1.uom).to eql(cil1.unit_of_measure)
    end
  end

  describe "generate_imports_from_ca_entry" do
    it "should generate DrawbackImportLines" do
      ent = Factory(:entry,importer:Factory(:importer,name:'EBC'),entry_number:'123456',eta_date:Date.new(2014,1,10),direct_shipment_date:Date.new(2013,12,24),carrier_name:'FEDEX',master_bills_of_lading:'MBOL')
      ci = Factory(:commercial_invoice,invoice_number:'INVNUM',entry:ent)
      cil1 = Factory(:commercial_invoice_line,commercial_invoice:ci,quantity:50,part_number:'pn1',unit_of_measure:'uom1',country_origin_code:'CN')
      ct1 = Factory(:commercial_invoice_tariff,commercial_invoice_line:cil1,hts_code:'1234567890',tariff_description:'td1',entered_value:'100',duty_amount:20,duty_rate:0.2)
      cil2 = Factory(:commercial_invoice_line,commercial_invoice:ci,quantity:23,part_number:'pn2',unit_of_measure:'uom2',country_origin_code:'GB')
      ct2 = Factory(:commercial_invoice_tariff,commercial_invoice_line:cil2,hts_code:'0987654321',tariff_description:'td2',entered_value:'100',duty_amount:20,duty_rate:0.2)
      expect { described_class.new.generate_imports_from_ca_entry(ent) }.to change(DrawbackImportLine,:count).from(0).to(2)
      ln = DrawbackImportLine.first
      expect(ln.importer).to eql(ent.importer)
      expect(ln.quantity).to eql(cil1.quantity)
      expect(ln.entry_number).to eql(ent.entry_number)
      expect(ln.import_date).to eql(ent.eta_date)
      expect(ln.country_of_origin_code).to eql(cil1.country_origin_code)
      expect(ln.part_number).to eql(cil1.part_number)
      expect(ln.hts_code).to eql(ct1.hts_code)
      expect(ln.description).to eql(ct1.tariff_description)
      expect(ln.unit_of_measure).to eql(cil1.unit_of_measure)
      expect(ln.unit_price).to eql(2)
      expect(ln.rate).to eql ct1.duty_rate
      expect(ln.duty_per_unit).to eql(0.4)
    end
  end
end