describe OpenChain::CustomHandler::LumberLiquidators::LumberValidationRuleCanadaEntryNafta do

  let(:cdefs) { described_class.prep_custom_definitions [:prod_fta] }

  let(:entry) do
    ent = FactoryBot(:entry)
    ent.commercial_invoices.build
    ent
  end

  it "passes if no invoice lines are connected to NAFTA-flagged products" do
    inv = entry.commercial_invoices.first
    inv.commercial_invoice_lines.build(part_number:"555")
    inv.commercial_invoice_lines.build(part_number:"666")
    inv.commercial_invoice_lines.build(part_number:"555")
    inv.commercial_invoice_lines.build(part_number:"777")
    # Doesn't connect to a product.  Probably shouldn't happen, but doesn't cause a failure of this rule.
    inv.commercial_invoice_lines.build(part_number:"888")
    inv.save!

    prod_1 = FactoryBot(:product, unique_identifier:"000000000555")
    prod_1.update_custom_value!(cdefs[:prod_fta], "nope")

    prod_2 = FactoryBot(:product, unique_identifier:"000000000666")
    prod_2.update_custom_value!(cdefs[:prod_fta], "also safe")

    # No custom definition for FTA for this product.  Shouldn't cause a failure of this rule.
    prod_3 = FactoryBot(:product, unique_identifier:"000000000777")

    expect(subject.run_validation entry).to be_nil
  end

  it "fails if invoice lines are connected to NAFTA-flagged products" do
    inv = entry.commercial_invoices.first
    inv.commercial_invoice_lines.build(part_number:"555")
    inv.commercial_invoice_lines.build(part_number:"666")
    inv.commercial_invoice_lines.build(part_number:"555")
    inv.commercial_invoice_lines.build(part_number:"777")
    inv.commercial_invoice_lines.build(part_number:nil)
    inv.commercial_invoice_lines.build(part_number:"555")
    inv.save!

    prod_1 = FactoryBot(:product, unique_identifier:"000000000555")
    prod_1.update_custom_value!(cdefs[:prod_fta], "NAFTA")

    prod_2 = FactoryBot(:product, unique_identifier:"000000000666")
    prod_2.update_custom_value!(cdefs[:prod_fta], "nafta")

    prod_3 = FactoryBot(:product, unique_identifier:"000000000777")
    prod_3.update_custom_value!(cdefs[:prod_fta], "DAFTA")

    # 555 message should show up only once even though it's on 3 lines.
    expect(subject.run_validation entry).to eq "Product '555' has been flagged for NAFTA review.\nProduct '666' has been flagged for NAFTA review."
  end

  it "handles internal percent signs and prevents SQL injection" do
    inv = entry.commercial_invoices.first
    # Not at all likely to be seen in real world use.
    inv.commercial_invoice_lines.build(part_number:"55%5")
    # This shoudln't match to anything.
    inv.commercial_invoice_lines.build(part_number:"' OR 1=1")
    inv.save!

    prod_1 = FactoryBot(:product, unique_identifier:"00000000055%5")
    prod_1.update_custom_value!(cdefs[:prod_fta], "NAFTA")

    expect(subject.run_validation entry).to eq "Product '55%5' has been flagged for NAFTA review."
  end

end