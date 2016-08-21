require "spec_helper"

describe OpenChain::Report::LandedCostDataGenerator do

  before :each do
    @entry = Factory(:entry, :file_logged_date=>Time.zone.now, :customer_name=>"Test", :customer_references=>"A\nB\nPO", :po_numbers=>"PO\nPO2", :importer_id=>5, :release_date=>Time.zone.now, :transport_mode_code=>"2")
    @bi = Factory(:broker_invoice, :entry=>@entry)

    @bi_line_brokerage = Factory(:broker_invoice_line, :broker_invoice => @bi, :charge_type=>"R", :charge_amount=> BigDecimal.new("100"))
    @bi_line_other = Factory(:broker_invoice_line, :broker_invoice => @bi, :charge_type=>"O", :charge_amount => BigDecimal.new("100"))
    @bi_line_freight = Factory(:broker_invoice_line, :broker_invoice => @bi, :charge_type=>"F", :charge_amount => BigDecimal.new("100"), charge_code: "0600")
    @bi_line_inland = Factory(:broker_invoice_line, :broker_invoice => @bi, :charge_type=>"T", :charge_amount => BigDecimal.new("100"))

    @ci = Factory(:commercial_invoice, :entry=>@entry, :invoice_number=>"INV1")
    @ci_line_1 = Factory(:commercial_invoice_line, :commercial_invoice=>@ci, :part_number=>"Part1", :quantity=>BigDecimal.new("11"), :po_number=>"PO", :mid=>"MID1", :country_origin_code=>"CN",
                          :hmf => BigDecimal.new("25"), :prorated_mpf => BigDecimal.new("25"), :cotton_fee =>  BigDecimal.new("50"), :commercial_invoice_tariffs=>[CommercialInvoiceTariff.new(:duty_amount=>BigDecimal.new("500"), :hts_code=>"1234567890", :entered_value=>BigDecimal.new("1000"))])

    @ci_line_2 = Factory(:commercial_invoice_line, :commercial_invoice=>@ci, :part_number=>"Part2", :quantity=>BigDecimal.new("11"), :po_number=>"PO2", :mid=>"MID2", :country_origin_code=>"TW",
                          :commercial_invoice_tariffs=>[CommercialInvoiceTariff.new(:duty_amount=>BigDecimal.new("250"), :entered_value=>BigDecimal.new("750"))])

    @ci_line_3 = Factory(:commercial_invoice_line, :commercial_invoice=>@ci, :part_number=>"Part3", :quantity=>BigDecimal.new("11"), :po_number=>"PO2", :mid=>"MID2", :country_origin_code=>"TW",
                          :commercial_invoice_tariffs=>[CommercialInvoiceTariff.new(:duty_amount=>BigDecimal.new("250"), :hts_code=>"9876543210", :entered_value=>BigDecimal.new("500")), CommercialInvoiceTariff.new(:duty_amount=>BigDecimal.new("250"), :hts_code=>"1234567890", :entered_value=>BigDecimal.new("500"))])
  end

  context "landed_cost_data_for_entry" do

    it "should calculate landed cost for a single entry" do
      lc = described_class.new.landed_cost_data_for_entry @entry
      expect(lc[:customer_name]).to eq(@entry.customer_name)
      expect(lc[:entries].size).to eq(1)
      e = lc[:entries].first
      expect(e[:broker_reference]).to eq(@entry.broker_reference)
      expect(e[:customer_references]).to eq(["PO", "PO2", "A", "B"])
      expect(e[:number_of_invoice_lines]).to eq(3)
      expect(e[:release_date]).to eq(@entry.release_date)
      expect(e[:transport_mode_code]).to eq(@entry.transport_mode_code)
      expect(e[:customer_reference]).to eq(@entry.customer_references.split("\n"))

      expect(e[:commercial_invoices].size).to eq(1)
      i = e[:commercial_invoices].first

      expect(i[:invoice_number]).to eq(@ci.invoice_number)
      expect(i[:first_logged]).to eq(@entry.file_logged_date)
      expect(i[:commercial_invoice_lines].size).to eq(3)

      l = i[:commercial_invoice_lines].first

      expect(l[:part_number]).to eq(@ci_line_1.part_number)
      expect(l[:po_number]).to eq(@ci_line_1.po_number)
      expect(l[:country_origin_code]).to eq(@ci_line_1.country_origin_code)
      expect(l[:mid]).to eq(@ci_line_1.mid)
      expect(l[:quantity]).to eq(@ci_line_1.quantity)
      expect(l[:hts_code]).to eq([@ci_line_1.commercial_invoice_tariffs.first.hts_code])

      # We gave each charge the same amount so we could just use the same per_unit proration for all checks
      per_unit = BigDecimal.new("100") / BigDecimal.new("33")

      expect(l[:entered_value]).to eq(@ci_line_1.commercial_invoice_tariffs.first.entered_value)
      expect(l[:duty]).to eq(@ci_line_1.commercial_invoice_tariffs.first.duty_amount)
      expect(l[:fee]).to eq(@ci_line_1.hmf + @ci_line_1.prorated_mpf + @ci_line_1.cotton_fee)
      expect(l[:brokerage]).to eq((per_unit * @ci_line_1.quantity).round(2, BigDecimal::ROUND_HALF_UP))
      expect(l[:other]).to eq((per_unit * @ci_line_1.quantity).round(2, BigDecimal::ROUND_HALF_UP))
      expect(l[:international_freight]).to eq((per_unit * @ci_line_1.quantity).round(2, BigDecimal::ROUND_HALF_UP))
      expect(l[:inland_freight]).to eq((per_unit * @ci_line_1.quantity).round(2, BigDecimal::ROUND_HALF_UP))
      expect(l[:landed_cost]).to eq(l[:entered_value] + l[:duty] + l[:fee] + l[:international_freight] + l[:inland_freight] + l[:brokerage]  + l[:other])
      expect(l[:hmf]).to eq(@ci_line_1.hmf)
      expect(l[:mpf]).to eq(@ci_line_1.prorated_mpf)
      expect(l[:cotton_fee]).to eq(@ci_line_1.cotton_fee)

      expect(l[:per_unit][:entered_value]).to eq(l[:entered_value] / @ci_line_1.quantity)
      expect(l[:per_unit][:duty]).to eq(l[:duty] / @ci_line_1.quantity)
      expect(l[:per_unit][:fee]).to eq(l[:fee] / @ci_line_1.quantity)
      expect(l[:per_unit][:brokerage]).to eq(l[:brokerage] / @ci_line_1.quantity)
      expect(l[:per_unit][:international_freight]).to eq(l[:international_freight] / @ci_line_1.quantity)
      expect(l[:per_unit][:inland_freight]).to eq(l[:inland_freight] / @ci_line_1.quantity)
      expect(l[:per_unit][:other]).to eq(l[:other] / @ci_line_1.quantity)
      expect(l[:per_unit][:landed_cost]).to eq(l[:landed_cost] / @ci_line_1.quantity)

      expect(l[:percentage][:entered_value]).to eq((l[:entered_value] / l[:landed_cost]) * BigDecimal.new("100"))
      expect(l[:percentage][:duty]).to eq((l[:duty] / l[:landed_cost]) * BigDecimal.new("100"))
      expect(l[:percentage][:fee]).to eq((l[:fee] / l[:landed_cost]) * BigDecimal.new("100"))
      expect(l[:percentage][:international_freight]).to eq((l[:international_freight] / l[:landed_cost]) * BigDecimal.new("100"))
      expect(l[:percentage][:inland_freight]).to eq((l[:inland_freight] / l[:landed_cost]) * BigDecimal.new("100"))
      expect(l[:percentage][:brokerage]).to eq((l[:brokerage] / l[:landed_cost]) * BigDecimal.new("100"))
      expect(l[:percentage][:other]).to eq((l[:other] / l[:landed_cost]) * BigDecimal.new("100"))

      # No point in validating the second line since it's going to be the same calculations as the first
      # The third line is interesting to us only because of the rounding calcuation we have to do with the prorated remainers
      # on 1 cent and the way we're summing multiple tariff lines
      l = i[:commercial_invoice_lines][2]

      expect(l[:entered_value]).to eq(@ci_line_3.commercial_invoice_tariffs.inject(BigDecimal.new("0")){|s, v| s + v.entered_value})
      expect(l[:duty]).to eq(BigDecimal.new("500")) # add two tariff lines together
      expect(l[:fee]).to eq(BigDecimal.new("0"))
      expect(l[:brokerage]).to eq(BigDecimal.new("33.34"))
      expect(l[:other]).to eq(BigDecimal.new("33.34"))
      expect(l[:international_freight]).to eq(BigDecimal.new("33.34"))
      expect(l[:inland_freight]).to eq(BigDecimal.new("33.34"))
      expect(l[:landed_cost]).to eq(l[:entered_value] + l[:duty] + l[:fee] + l[:international_freight] + l[:inland_freight] + l[:brokerage]  + l[:other])

      # Make sure the unique hts codes were gathered
      expect(l[:hts_code]).to eq([@ci_line_3.commercial_invoice_tariffs.first.hts_code, @ci_line_3.commercial_invoice_tariffs.second.hts_code])

      expect(e[:totals][:entered_value]).to eq(BigDecimal.new("2750"))
      expect(e[:totals][:duty]).to eq(BigDecimal.new("1250"))
      expect(e[:totals][:fee]).to eq(BigDecimal.new("100"))
      expect(e[:totals][:international_freight]).to eq(BigDecimal.new("100"))
      expect(e[:totals][:inland_freight]).to eq(BigDecimal.new("100"))
      expect(e[:totals][:brokerage]).to eq(BigDecimal.new("100"))
      expect(e[:totals][:other]).to eq(BigDecimal.new("100"))
      expect(e[:totals][:landed_cost]).to eq(e[:totals][:entered_value] + e[:totals][:duty] + e[:totals][:fee] + e[:totals][:international_freight] +
                                           e[:totals][:inland_freight] + e[:totals][:brokerage]  + e[:totals][:other])

      expect(e[:percentage][:entered_value]).to eq((BigDecimal.new("2750") / e[:totals][:landed_cost]) * BigDecimal.new("100"))
      expect(e[:percentage][:duty]).to eq((BigDecimal.new("1250") / e[:totals][:landed_cost]) * BigDecimal.new("100"))
      expect(e[:percentage][:fee]).to eq((BigDecimal.new("100") / e[:totals][:landed_cost]) * BigDecimal.new("100"))
      expect(e[:percentage][:international_freight]).to eq((BigDecimal.new("100") / e[:totals][:landed_cost]) * BigDecimal.new("100"))
      expect(e[:percentage][:inland_freight]).to eq((BigDecimal.new("100") / e[:totals][:landed_cost]) * BigDecimal.new("100"))
      expect(e[:percentage][:brokerage]).to eq((BigDecimal.new("100") / e[:totals][:landed_cost]) * BigDecimal.new("100"))
      expect(e[:percentage][:other]).to eq((BigDecimal.new("100") / e[:totals][:landed_cost]) * BigDecimal.new("100"))

      expect(lc[:totals][:entered_value]).to eq(BigDecimal.new("2750"))
      expect(lc[:totals][:duty]).to eq(BigDecimal.new("1250"))
      expect(lc[:totals][:fee]).to eq(BigDecimal.new("100"))
      expect(lc[:totals][:international_freight]).to eq(BigDecimal.new("100"))
      expect(lc[:totals][:inland_freight]).to eq(BigDecimal.new("100"))
      expect(lc[:totals][:brokerage]).to eq(BigDecimal.new("100"))
      expect(lc[:totals][:other]).to eq(BigDecimal.new("100"))

    end

    it "should take an entry id for calculating landed costs" do
      lc = described_class.new.landed_cost_data_for_entry @entry.id

      expect(lc[:totals][:entered_value]).to eq(BigDecimal.new("2750"))
      expect(lc[:totals][:duty]).to eq(BigDecimal.new("1250"))
      expect(lc[:totals][:fee]).to eq(BigDecimal.new("100"))
      expect(lc[:totals][:international_freight]).to eq(BigDecimal.new("100"))
      expect(lc[:totals][:inland_freight]).to eq(BigDecimal.new("100"))
      expect(lc[:totals][:brokerage]).to eq(BigDecimal.new("100"))
      expect(lc[:totals][:other]).to eq(BigDecimal.new("100"))
    end

    it "should prorate international freight against a single invoice if specified" do
      # Create a second invoice and move one of the other lines to the new invoice
      ci_2 = Factory(:commercial_invoice, :entry=>@entry, :invoice_number=>"INV2")
      ci_2_line_1 = Factory(:commercial_invoice_line, :commercial_invoice=>ci_2, :part_number=>"Part4", :quantity=>BigDecimal.new("11"), :po_number=>"PO", :mid=>"MID4", :country_origin_code=>"CN", :value => BigDecimal.new("1000"),
                            :commercial_invoice_tariffs=>[CommercialInvoiceTariff.new(:duty_amount=>BigDecimal.new("500"))])

      @bi.broker_invoice_lines.create :charge_type=>"F", :charge_amount => BigDecimal.new("100"), :charge_description=> ci_2.invoice_number, :charge_code=>"0600"

      
      lc = described_class.new.landed_cost_data_for_entry @entry.id

      e = lc[:entries].first
      expect(e[:commercial_invoices].size).to eq(2)
      i = e[:commercial_invoices].first
      l = i[:commercial_invoice_lines]
      expect(l.size).to eq(3)

      i = e[:commercial_invoices].second
      l = i[:commercial_invoice_lines]
      expect(l.size).to eq(1)
      l = i[:commercial_invoice_lines].first

      # The second item should have had all the new int'l freight charge applied to it as well as its share of the "global" int'l freight charge
      global_freight_proration = (@bi_line_freight.charge_amount / BigDecimal.new("44"))
      expect(l[:international_freight]).to eq((BigDecimal.new("100") + (global_freight_proration * ci_2_line_1.quantity)).round(2, BigDecimal::ROUND_HALF_UP))
      expect(lc[:totals][:international_freight]).to eq(BigDecimal.new("200"))
    end

    it "should prorate international freight against a single invoice if specified - fuzzy freight invoice matching" do
      # Create a second invoice and move one of the other lines to the new invoice
      ci_2 = Factory(:commercial_invoice, :entry=>@entry, :invoice_number=>"INV2")
      ci_2_line_1 = Factory(:commercial_invoice_line, :commercial_invoice=>ci_2, :part_number=>"Part4", :quantity=>BigDecimal.new("11"), :po_number=>"PO", :mid=>"MID4", :country_origin_code=>"CN", :value => BigDecimal.new("1000"),
                            :commercial_invoice_tariffs=>[CommercialInvoiceTariff.new(:duty_amount=>BigDecimal.new("500"))])

      @bi.broker_invoice_lines.create :charge_type=>"F", :charge_amount => BigDecimal.new("100"), :charge_description=> "Test#{ci_2.invoice_number}", :charge_code=>"0600"

      
      lc = described_class.new.landed_cost_data_for_entry @entry.id

      e = lc[:entries].first
      expect(e[:commercial_invoices].size).to eq(2)
      i = e[:commercial_invoices].first
      l = i[:commercial_invoice_lines]
      expect(l.size).to eq(3)

      i = e[:commercial_invoices].second
      l = i[:commercial_invoice_lines]
      expect(l.size).to eq(1)
      l = i[:commercial_invoice_lines].first

      # The second item should have had all the new int'l freight charge applied to it as well as its share of the "global" int'l freight charge
      global_freight_proration = (@bi_line_freight.charge_amount / BigDecimal.new("44"))
      expect(l[:international_freight].to_s("F")).to eq((BigDecimal.new("100") + (global_freight_proration * ci_2_line_1.quantity)).round(2, BigDecimal::ROUND_HALF_UP).to_s("F"))
      expect(lc[:totals][:international_freight]).to eq(BigDecimal.new("200"))
    end

    it "detects and applies freight charges for freight lines other than 0600" do
      # This is testing the case where we are passing through our own breakbulk charges (.ie we're doing the freight handling)
      # and the freight charges come through as non-0600 lines.

      @bi_line_other.update_attributes! charge_code: "ABCD"
      @bi.broker_invoice_lines.create :charge_type=>"F", :charge_amount => BigDecimal.new("100"), :charge_description=> "Test", :charge_code=>"9999"
      @bi.broker_invoice_lines.create :charge_type=>"C", :charge_amount => BigDecimal.new("100"), :charge_description=> "Test", :charge_code=>"1111"

      DataCrossReference.create! key: "ABCD", cross_reference_type: DataCrossReference::ALLIANCE_FREIGHT_CHARGE_CODE
      DataCrossReference.create! key: "9999", cross_reference_type: DataCrossReference::ALLIANCE_FREIGHT_CHARGE_CODE
      DataCrossReference.create! key: "1111", cross_reference_type: DataCrossReference::ALLIANCE_FREIGHT_CHARGE_CODE


      lc = described_class.new.landed_cost_data_for_entry @entry.id

      e = lc[:entries].first
      i = e[:commercial_invoices].first
      l = i[:commercial_invoice_lines].first

      # 400 is the sum of all freight charge lines, 33 is total # of units on invoice
      per_unit = BigDecimal.new("400") / BigDecimal.new("33")
      expect(l[:international_freight]).to eq (per_unit * @ci_line_1.quantity).round(2, BigDecimal::ROUND_HALF_UP)
      expect(l[:per_unit][:international_freight]).to eq(l[:international_freight] / @ci_line_1.quantity)
      expect(l[:percentage][:international_freight]).to eq((l[:international_freight] / l[:landed_cost]) * BigDecimal.new("100"))
      # Since we switched the "O" charge line to a freight line via the charge code type, make sure this was taken into account 
      # and our other charges are now 0
      expect(l[:other]).to eq(BigDecimal.new("0"))

      expect(e[:totals][:other]).to eq(BigDecimal.new("0"))
      expect(e[:totals][:international_freight]).to eq(BigDecimal.new("400"))
      expect(e[:percentage][:international_freight]).to eq((BigDecimal.new("400") / e[:totals][:landed_cost]) * BigDecimal.new("100"))
    end

    it "handles cotton fee specified only at the header" do
      @ci.commercial_invoice_lines.each {|l| l.update_attributes! cotton_fee: 0}
      @entry.update_attributes! cotton_fee: BigDecimal("5")

      lc = described_class.new.landed_cost_data_for_entry @entry.id
      invoice = lc[:entries].first[:commercial_invoices].first

      line = invoice[:commercial_invoice_lines].first
      expect(line[:cotton_fee]).to eq BigDecimal("1.82")
      expect(line[:fee]).to eq BigDecimal("51.82")
      expect(line[:per_unit][:fee].round(2)).to eq BigDecimal("4.71")

      line = invoice[:commercial_invoice_lines].second
      expect(line[:cotton_fee]).to eq BigDecimal("1.36")
      expect(line[:fee]).to eq BigDecimal("1.36")
      expect(line[:per_unit][:fee].round(2)).to eq BigDecimal("0.12")

      line = invoice[:commercial_invoice_lines][2]
      expect(line[:cotton_fee]).to eq BigDecimal("1.82")
      expect(line[:fee]).to eq BigDecimal("1.82")
      expect(line[:per_unit][:fee].round(2)).to eq BigDecimal("0.17")
    end

    it "doesn't hang if no lines have an entered_value and there is a header level cotton fee" do
      @ci.commercial_invoice_lines.each {|l| l.update_attributes! cotton_fee: 0; l.commercial_invoice_tariffs.update_all(entered_value: 0)}
      @entry.update_attributes! cotton_fee: BigDecimal("5")
      lc = described_class.new.landed_cost_data_for_entry @entry.id
      # by virtue of not hanging...this spec passes
    end
  end
end
