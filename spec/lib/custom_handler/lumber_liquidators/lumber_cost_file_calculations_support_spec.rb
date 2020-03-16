describe OpenChain::CustomHandler::LumberLiquidators::LumberCostFileCalculationsSupport do
  subject { Class.new { include OpenChain::CustomHandler::LumberLiquidators::LumberCostFileCalculationsSupport}.new }

  def add_charges inv
    inv.broker_invoice_lines.build charge_code: '0004', charge_amount: BigDecimal("10"), charge_description: "Ocean Rate"
    inv.broker_invoice_lines.build charge_code: '0007', charge_amount: BigDecimal("20"), charge_description: "Brokerage"
    inv.broker_invoice_lines.build charge_code: '0176', charge_amount: BigDecimal("30"), charge_description: "Acessorial"
    inv.broker_invoice_lines.build charge_code: '0050', charge_amount: BigDecimal("40"), charge_description: "Acessorial"
    inv.broker_invoice_lines.build charge_code: '0142', charge_amount: BigDecimal("50"), charge_description: "Acessorial"
    inv.broker_invoice_lines.build charge_code: '0235', charge_amount: BigDecimal("60"), charge_description: "ISC Management"
    inv.broker_invoice_lines.build charge_code: '0191', charge_amount: BigDecimal("70"), charge_description: "ISF"
    inv.broker_invoice_lines.build charge_code: '0915', charge_amount: BigDecimal("80"), charge_description: "ISF"
    inv.broker_invoice_lines.build charge_code: '0189', charge_amount: BigDecimal("90"), charge_description: "Pier Pass"
    inv.broker_invoice_lines.build charge_code: '0720', charge_amount: BigDecimal("100"), charge_description: "Pier Pass"
    inv.broker_invoice_lines.build charge_code: '0739', charge_amount: BigDecimal("110"), charge_description: "Pier Pass"
    inv.broker_invoice_lines.build charge_code: '0212', charge_amount: BigDecimal("120"), charge_description: "Inland Freight"
    inv.broker_invoice_lines.build charge_code: '0016', charge_amount: BigDecimal("130"), charge_description: "Courier"
    inv.broker_invoice_lines.build charge_code: '0031', charge_amount: BigDecimal("140"), charge_description: "OGA"
    inv.broker_invoice_lines.build charge_code: '0125', charge_amount: BigDecimal("150"), charge_description: "OGA"
    inv.broker_invoice_lines.build charge_code: '0026', charge_amount: BigDecimal("160"), charge_description: "OGA"
    inv.broker_invoice_lines.build charge_code: '0193', charge_amount: BigDecimal("170"), charge_description: "Clean Truck"
    inv.broker_invoice_lines.build charge_code: '0196', charge_amount: BigDecimal("180"), charge_description: "Clean Truck"
    # Add a charge that will get ignored
    inv.broker_invoice_lines.build charge_code: '1111', charge_amount: BigDecimal("180"), charge_description: "Ignored"
  end

  let (:entry) {
    e = Entry.new
    inv = e.broker_invoices.build
    add_charges(inv)

    inv = e.broker_invoices.build
    add_charges(inv)

    e
  }

  describe "calculate_charge_totals" do
    it "calculates the charge totals for all invoices on an entry" do
      totals = subject.calculate_charge_totals entry
      expect(totals.size).to eq 10

      expect(totals[:ocean_rate]).to eq 20
      expect(totals[:brokerage]).to eq 40
      expect(totals[:acessorial]).to eq 240
      expect(totals[:isc_management]).to eq 120
      expect(totals[:isf]).to eq 300
      expect(totals[:pier_pass]).to eq 600
      expect(totals[:inland_freight]).to eq 240
      expect(totals[:courier]).to eq 260
      expect(totals[:oga]).to eq 900
      expect(totals[:clean_truck]).to eq 700
    end
  end

  describe "calculate_proration_for_lines" do

    let (:entry) {
      entry = Factory(:entry)
      # This second invoice exists only so that 50% of the charge amount is considered for proration against our
      # test line(s), which all belong to a different invoice, for gross-weight-based prorations.  The actual
      # gross weight of this line doesn't matter.  It's 100 and the other line is 50, but the two invoices are
      # to be distributed charge prorations 50/50.
      other_inv = entry.commercial_invoices.build gross_weight:BigDecimal("100")
      entry
    }

    let (:line) {
      inv = entry.commercial_invoices.build gross_weight:BigDecimal("50")
      line = inv.commercial_invoice_lines.build add_duty_amount: BigDecimal("10"), cvd_duty_amount: BigDecimal("20"), hmf: BigDecimal("30"), prorated_mpf: BigDecimal("40")
      line.commercial_invoice_tariffs.build entered_value: BigDecimal("30.00"), duty_amount: BigDecimal("90"), gross_weight:BigDecimal("10.00")
      line.commercial_invoice_tariffs.build entered_value: BigDecimal("3.33"), duty_amount: BigDecimal("10"), gross_weight:BigDecimal("1.11")

      line
    }
    it "calculates prorated amounts for a commercial invoice lines using entered value percentages" do
      totals = {ocean_rate: BigDecimal("100"), brokerage: BigDecimal("200")}
      bucket = totals.dup

      charges = subject.calculate_proration_for_lines line, BigDecimal("100"), totals, bucket

      expect(charges[:entered_value]).to eq BigDecimal("33.33")
      expect(charges[:duty]).to eq 100
      expect(charges[:add]).to eq 10
      expect(charges[:cvd]).to eq 20
      expect(charges[:hmf]).to eq 30
      expect(charges[:mpf]).to eq 40
      # At this point, a straight proration by the exact percentage of the entered value for the line
      # has taken place.  Any remainder values should be in the bucket.
      expect(charges[:ocean_rate]).to eq BigDecimal("10.00")
      expect(charges[:brokerage]).to eq BigDecimal("66.66")

      expect(bucket[:ocean_rate]).to eq BigDecimal("90.00")
      expect(bucket[:brokerage]).to eq BigDecimal("133.34")
    end

    it "does not remove more from the proration bucket than is present in it" do
      totals = {ocean_rate: BigDecimal("100"), brokerage: BigDecimal("200")}
      bucket = {ocean_rate: BigDecimal("10"), brokerage: BigDecimal("20")}

      # Becuase the expected proration amount should be more than is actually in the bucket, 
      # the method should not pull more value than is present.
      charges = subject.calculate_proration_for_lines line, BigDecimal("100"), totals, bucket

      expect(charges[:ocean_rate]).to eq 10
      expect(charges[:brokerage]).to eq 20

      expect(bucket[:ocean_rate]).to eq 0
      expect(bucket[:brokerage]).to eq 0
    end

    it "handles multiple lines" do
      totals = {ocean_rate: BigDecimal("100"), brokerage: BigDecimal("200")}
      bucket = totals.dup

      charges = subject.calculate_proration_for_lines [line, line, line], BigDecimal("200"), totals, bucket

      expect(charges[:entered_value]).to eq BigDecimal("99.99")
      expect(charges[:duty]).to eq 300
      expect(charges[:add]).to eq 30
      expect(charges[:cvd]).to eq 60
      expect(charges[:hmf]).to eq 90
      expect(charges[:mpf]).to eq 120
      expect(charges[:ocean_rate]).to eq BigDecimal("30.00")
      expect(charges[:brokerage]).to eq BigDecimal("99.99")

      expect(bucket[:ocean_rate]).to eq BigDecimal("70.00")
      expect(bucket[:brokerage]).to eq BigDecimal("100.01")
    end
  end

  describe "add_remaining_proration_amounts" do

    it "splits any remaining values from the charge buckets over all the value hashes" do
      bucket_remainder = {brokerage: BigDecimal("0.01"), ocean_rate: BigDecimal("0.1")}
      values = [{brokerage: BigDecimal("0"), ocean_rate: BigDecimal("0"), entered_value: 10}, {brokerage: BigDecimal("0"), ocean_rate: BigDecimal("0"), entered_value: 10},{brokerage: BigDecimal("0"), ocean_rate: BigDecimal("0"), entered_value: 10}]

      subject.add_remaining_proration_amounts values, bucket_remainder

      expect(values.first[:brokerage]).to eq BigDecimal("0.004")
      expect(values.second[:brokerage]).to eq BigDecimal("0.003")
      expect(values.third[:brokerage]).to eq BigDecimal("0.003")

      expect(values.first[:ocean_rate]).to eq BigDecimal("0.034")
      expect(values.second[:ocean_rate]).to eq BigDecimal("0.033")
      expect(values.third[:ocean_rate]).to eq BigDecimal("0.033")
    end

    it "skips values that have no entered value on them" do
      bucket_remainder = {brokerage: BigDecimal("0.01")}
      values = [{brokerage: BigDecimal("0"), ocean_rate: BigDecimal("0"), entered_value: 10}, {brokerage: BigDecimal("0"), ocean_rate: BigDecimal("0"), entered_value: 10},{brokerage: BigDecimal("0"), ocean_rate: BigDecimal("0"), entered_value: 0}]

      subject.add_remaining_proration_amounts values, bucket_remainder

      expect(values.first[:brokerage]).to eq BigDecimal("0.005")
      expect(values.second[:brokerage]).to eq BigDecimal("0.005")
      expect(values.third[:brokerage]).to eq 0
    end

    it "does not loop continuously if no lines have entered values" do
      bucket_remainder = {brokerage: BigDecimal("0.01")}
      values = [{brokerage: BigDecimal("0"), ocean_rate: BigDecimal("0")}, {brokerage: BigDecimal("0"), ocean_rate: BigDecimal("0")}]

      expect {subject.add_remaining_proration_amounts values, bucket_remainder}.to raise_error "Detected infinite loop condition.  No modifications made to the charge bucket."
    end
  end
end