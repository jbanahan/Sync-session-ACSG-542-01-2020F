module OpenChain; module CustomHandler; module EddieBauer; class EddieBauerCaDrawbackGenerator
  def generate_exports_from_us_entry ent
    ent.commercial_invoice_lines.each do |cil|
      d = DutyCalcExportFileLine.new
      d.importer = ent.importer
      d.export_date = ent.export_date
      d.ship_date = ent.export_date
      d.part_number = cil.part_number
      d.carrier = ent.carrier_name
      d.ref_1 = ent.entry_number
      d.ref_2 = ent.master_bills_of_lading
      d.ref_3 = cil.id.to_s
      d.destination_country = 'US'
      d.quantity = cil.quantity
      d.uom = cil.unit_of_measure
      ct = cil.commercial_invoice_tariffs.order('hts_code ASC').first
      if ct
        d.hts_code = ct.hts_code
        d.description = ct.tariff_description
      end
      d.save!
    end
  end

  def generate_imports_from_ca_entry ent
    ent.commercial_invoice_lines.each do |cil|
      d = DrawbackImportLine.new
      d.importer = ent.importer
      d.quantity = cil.quantity
      d.entry_number = ent.entry_number
      d.import_date = ent.eta_date
      d.country_of_origin_code = cil.country_origin_code
      d.part_number = cil.part_number
      d.product = Product.where(unique_identifier:"EDDIE-#{cil.part_number}").first_or_create!
      ct = cil.commercial_invoice_tariffs.order('hts_code ASC').first
      d.hts_code = ct.hts_code
      d.description = ct.tariff_description
      d.unit_of_measure = cil.unit_of_measure
      d.unit_price = ct.entered_value / cil.quantity
      d.rate = ct.duty_rate
      d.duty_per_unit = ct.duty_amount / cil.quantity
      d.save!            
    end
    
  end
end; end; end; end