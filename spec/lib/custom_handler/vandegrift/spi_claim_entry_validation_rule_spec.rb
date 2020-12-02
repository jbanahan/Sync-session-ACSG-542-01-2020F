describe OpenChain::CustomHandler::Vandegrift::SpiClaimEntryValidationRule do
  let(:entry) do
    ent = create(:entry, export_country_codes: "CN\n IN", origin_country_codes: "NO\n FI")
    ent.commercial_invoices.build(invoice_number: 'INV-XYZ')
    ent
  end

  it 'passes if all invoice lines have SPI set' do
    DataCrossReference.create!(cross_reference_type: DataCrossReference::SPI_AVAILABLE_COUNTRY_COMBINATION, key: DataCrossReference.make_compound_key('CN', 'NO'), value: 'X')

    inv = entry.commercial_invoices.first
    line_1 = inv.commercial_invoice_lines.build
    line_1.commercial_invoice_tariffs.build(spi_primary: 'X')
    # This shouldn't matter since the other tariff under this line has a primary SPI.
    line_1.commercial_invoice_tariffs.build(spi_primary: ' ')
    line_2 = inv.commercial_invoice_lines.build
    line_2.commercial_invoice_tariffs.build(spi_primary: 'Y')
    inv.save!

    entry.reload

    expect(subject.run_validation(entry)).to be_nil
  end

  it "passes if SPI is not set but there's no SPI available for the export/origin country combo" do
    inv = entry.commercial_invoices.first
    line_1 = inv.commercial_invoice_lines.build
    line_1.commercial_invoice_tariffs.build(spi_primary: ' ')
    line_2 = inv.commercial_invoice_lines.build
    line_2.commercial_invoice_tariffs.build(spi_primary: nil)
    inv.save!

    expect(subject.run_validation(entry)).to be_nil
  end

  it 'fails if SPI is not set and export/origin country xref indicates there is SPI available' do
    DataCrossReference.create!(cross_reference_type: DataCrossReference::SPI_AVAILABLE_COUNTRY_COMBINATION, key: DataCrossReference.make_compound_key('IN', 'FI'), value: 'X')

    inv = entry.commercial_invoices.first
    line_1 = inv.commercial_invoice_lines.build(line_number: 1)
    line_1.commercial_invoice_tariffs.build(spi_primary: ' ')
    line_2 = inv.commercial_invoice_lines.build(line_number: 2)
    line_2.commercial_invoice_tariffs.build(spi_primary: nil)
    inv.save!

    expect(subject.run_validation(entry)).to eq "Invoice INV-XYZ, Line 1: No SPI claimed. Please review for applicability.\n" +
                                                'Invoice INV-XYZ, Line 2: No SPI claimed. Please review for applicability.'
  end
end
