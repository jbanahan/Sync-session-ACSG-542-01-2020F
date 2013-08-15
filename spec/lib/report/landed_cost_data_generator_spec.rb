require "spec_helper"

describe OpenChain::Report::LandedCostDataGenerator do

  before :each do
    @entry = Factory(:entry, :file_logged_date=>Time.zone.now, :customer_name=>"Test", :customer_references=>"A\nB\nPO", :po_numbers=>"PO\nPO2", :importer_id=>5)
    @bi = Factory(:broker_invoice, :entry=>@entry)

    @bi_line_brokerage = Factory(:broker_invoice_line, :broker_invoice => @bi, :charge_type=>"R", :charge_amount=> BigDecimal.new("100"))
    @bi_line_other = Factory(:broker_invoice_line, :broker_invoice => @bi, :charge_type=>"O", :charge_amount => BigDecimal.new("100"))
    @bi_line_freight = Factory(:broker_invoice_line, :broker_invoice => @bi, :charge_type=>"F", :charge_amount => BigDecimal.new("100"))
    @bi_line_inland = Factory(:broker_invoice_line, :broker_invoice => @bi, :charge_type=>"T", :charge_amount => BigDecimal.new("100"))

    @ci = Factory(:commercial_invoice, :entry=>@entry, :invoice_number=>"INV1")
    @ci_line_1 = Factory(:commercial_invoice_line, :commercial_invoice=>@ci, :part_number=>"Part1", :quantity=>BigDecimal.new("11"), :po_number=>"PO", :mid=>"MID1", :country_origin_code=>"CN", :value => BigDecimal.new("1000"),
                          :hmf => BigDecimal.new("25"), :mpf => BigDecimal.new("25"), :cotton_fee =>  BigDecimal.new("50"), :commercial_invoice_tariffs=>[CommercialInvoiceTariff.new(:duty_amount=>BigDecimal.new("500"))])

    @ci_line_2 = Factory(:commercial_invoice_line, :commercial_invoice=>@ci, :part_number=>"Part2", :quantity=>BigDecimal.new("11"), :po_number=>"PO2", :mid=>"MID2", :country_origin_code=>"TW", :value => BigDecimal.new("750"),
                          :commercial_invoice_tariffs=>[CommercialInvoiceTariff.new(:duty_amount=>BigDecimal.new("250"))])

    @ci_line_3 = Factory(:commercial_invoice_line, :commercial_invoice=>@ci, :part_number=>"Part3", :quantity=>BigDecimal.new("11"), :po_number=>"PO2", :mid=>"MID2", :country_origin_code=>"TW", :value => BigDecimal.new("1000"),
                          :commercial_invoice_tariffs=>[CommercialInvoiceTariff.new(:duty_amount=>BigDecimal.new("250")), CommercialInvoiceTariff.new(:duty_amount=>BigDecimal.new("250"))])
  end

  context :landed_cost_data_for_entry do

    it "should calculate landed cost for a single entry" do
      lc = described_class.new.landed_cost_data_for_entry @entry
      lc[:customer_name].should == @entry.customer_name
      lc[:entries].should have(1).item
      e = lc[:entries].first
      e[:broker_reference].should == @entry.broker_reference
      e[:customer_references].should == ["PO", "PO2", "A", "B"]
      e[:number_of_invoice_lines].should == 3

      e[:commercial_invoices].should have(1).item
      i = e[:commercial_invoices].first

      i[:invoice_number].should == @ci.invoice_number
      i[:first_logged].should == @entry.file_logged_date
      i[:commercial_invoice_lines].should have(3).items

      l = i[:commercial_invoice_lines].first

      l[:part_number].should == @ci_line_1.part_number
      l[:po_number].should == @ci_line_1.po_number
      l[:country_origin_code].should == @ci_line_1.country_origin_code
      l[:mid].should == @ci_line_1.mid
      l[:quantity].should == @ci_line_1.quantity

      # We gave each charge the same amount so we could just use the same per_unit proration for all checks
      per_unit = BigDecimal.new("100") / BigDecimal.new("33")

      l[:entered_value].should == @ci_line_1.value
      l[:duty].should == @ci_line_1.commercial_invoice_tariffs.first.duty_amount
      l[:fee].should == @ci_line_1.hmf + @ci_line_1.mpf + @ci_line_1.cotton_fee
      l[:brokerage].should == (per_unit * @ci_line_1.quantity).round(2, BigDecimal::ROUND_HALF_UP)
      l[:other].should == (per_unit * @ci_line_1.quantity).round(2, BigDecimal::ROUND_HALF_UP)
      l[:international_freight].should == (per_unit * @ci_line_1.quantity).round(2, BigDecimal::ROUND_HALF_UP)
      l[:inland_freight].should == (per_unit * @ci_line_1.quantity).round(2, BigDecimal::ROUND_HALF_UP)
      l[:landed_cost].should == (l[:entered_value] + l[:duty] + l[:fee] + l[:international_freight] + l[:inland_freight] + l[:brokerage]  + l[:other])

      l[:per_unit][:entered_value].should == (@ci_line_1.value / @ci_line_1.quantity)
      l[:per_unit][:duty].should == (l[:duty] / @ci_line_1.quantity)
      l[:per_unit][:fee].should == (l[:fee] / @ci_line_1.quantity)
      l[:per_unit][:brokerage].should == (l[:brokerage] / @ci_line_1.quantity)
      l[:per_unit][:international_freight].should == (l[:international_freight] / @ci_line_1.quantity)
      l[:per_unit][:inland_freight].should == (l[:inland_freight] / @ci_line_1.quantity)
      l[:per_unit][:other].should == (l[:other] / @ci_line_1.quantity)
      l[:per_unit][:landed_cost].should == (l[:landed_cost] / @ci_line_1.quantity)

      l[:percentage][:entered_value].should == ((l[:entered_value] / l[:landed_cost]) * BigDecimal.new("100"))
      l[:percentage][:duty].should == ((l[:duty] / l[:landed_cost]) * BigDecimal.new("100"))
      l[:percentage][:fee].should == ((l[:fee] / l[:landed_cost]) * BigDecimal.new("100"))
      l[:percentage][:international_freight].should == ((l[:international_freight] / l[:landed_cost]) * BigDecimal.new("100"))
      l[:percentage][:inland_freight].should == ((l[:inland_freight] / l[:landed_cost]) * BigDecimal.new("100"))
      l[:percentage][:brokerage].should == ((l[:brokerage] / l[:landed_cost]) * BigDecimal.new("100"))
      l[:percentage][:other].should == ((l[:other] / l[:landed_cost]) * BigDecimal.new("100"))

      # No point in validating the second line since it's going to be the same calculations as the first
      # The third line is interesting to us only because of the rounding calcuation we have to do with the prorated remainers
      # on 1 cent and the way we're summing multiple tariff lines
      l = i[:commercial_invoice_lines][2]

      l[:entered_value].should == @ci_line_3.value
      l[:duty].should == BigDecimal.new("500") # add two tariff lines together
      l[:fee].should == BigDecimal.new("0")
      l[:brokerage].should == BigDecimal.new("33.34")
      l[:other].should ==  BigDecimal.new("33.34")
      l[:international_freight].should ==  BigDecimal.new("33.34")
      l[:inland_freight].should ==  BigDecimal.new("33.34")
      l[:landed_cost].should == (l[:entered_value] + l[:duty] + l[:fee] + l[:international_freight] + l[:inland_freight] + l[:brokerage]  + l[:other])

      e[:totals][:entered_value].should == BigDecimal.new("2750")
      e[:totals][:duty].should == BigDecimal.new("1250")
      e[:totals][:fee].should == BigDecimal.new("100")
      e[:totals][:international_freight].should == BigDecimal.new("100")
      e[:totals][:inland_freight].should == BigDecimal.new("100")
      e[:totals][:brokerage].should == BigDecimal.new("100")
      e[:totals][:other].should == BigDecimal.new("100")
      e[:totals][:landed_cost].should == (e[:totals][:entered_value] + e[:totals][:duty] + e[:totals][:fee] + e[:totals][:international_freight] +
                                           e[:totals][:inland_freight] + e[:totals][:brokerage]  + e[:totals][:other])

      e[:percentage][:entered_value].should == (BigDecimal.new("2750") / e[:totals][:landed_cost]) * BigDecimal.new("100")
      e[:percentage][:duty].should == (BigDecimal.new("1250") / e[:totals][:landed_cost]) * BigDecimal.new("100")
      e[:percentage][:fee].should == (BigDecimal.new("100") / e[:totals][:landed_cost]) * BigDecimal.new("100")
      e[:percentage][:international_freight].should == (BigDecimal.new("100") / e[:totals][:landed_cost]) * BigDecimal.new("100")
      e[:percentage][:inland_freight].should == (BigDecimal.new("100") / e[:totals][:landed_cost]) * BigDecimal.new("100")
      e[:percentage][:brokerage].should == (BigDecimal.new("100") / e[:totals][:landed_cost]) * BigDecimal.new("100")
      e[:percentage][:other].should == (BigDecimal.new("100") / e[:totals][:landed_cost]) * BigDecimal.new("100")

      lc[:totals][:entered_value].should == BigDecimal.new("2750")
      lc[:totals][:duty].should == BigDecimal.new("1250")
      lc[:totals][:fee].should == BigDecimal.new("100")
      lc[:totals][:international_freight].should == BigDecimal.new("100")
      lc[:totals][:inland_freight].should == BigDecimal.new("100")
      lc[:totals][:brokerage].should == BigDecimal.new("100")
      lc[:totals][:other].should == BigDecimal.new("100")

    end

    it "should take an entry id for calculating landed costs" do
      lc = described_class.new.landed_cost_data_for_entry @entry.id

      lc[:totals][:entered_value].should == BigDecimal.new("2750")
      lc[:totals][:duty].should == BigDecimal.new("1250")
      lc[:totals][:fee].should == BigDecimal.new("100")
      lc[:totals][:international_freight].should == BigDecimal.new("100")
      lc[:totals][:inland_freight].should == BigDecimal.new("100")
      lc[:totals][:brokerage].should == BigDecimal.new("100")
      lc[:totals][:other].should == BigDecimal.new("100")
    end

    it "should prorate international freight against a single invoice if specified" do
      # Create a second invoice and move one of the other lines to the new invoice
      ci_2 = Factory(:commercial_invoice, :entry=>@entry, :invoice_number=>"INV2")
      ci_2_line_1 = Factory(:commercial_invoice_line, :commercial_invoice=>ci_2, :part_number=>"Part4", :quantity=>BigDecimal.new("11"), :po_number=>"PO", :mid=>"MID4", :country_origin_code=>"CN", :value => BigDecimal.new("1000"),
                            :commercial_invoice_tariffs=>[CommercialInvoiceTariff.new(:duty_amount=>BigDecimal.new("500"))])

      @bi.broker_invoice_lines.create :charge_type=>"F", :charge_amount => BigDecimal.new("100"), :charge_description=> ci_2.invoice_number, :charge_code=>"0600"

      
      lc = described_class.new.landed_cost_data_for_entry @entry.id

      e = lc[:entries].first
      e[:commercial_invoices].should have(2).items
      i = e[:commercial_invoices].first
      l = i[:commercial_invoice_lines]
      l.should have(3).items

      i = e[:commercial_invoices].second
      l = i[:commercial_invoice_lines]
      l.should have(1).item
      l = i[:commercial_invoice_lines].first

      # The second item should have had all the new int'l freight charge applied to it as well as its share of the "global" int'l freight charge
      global_freight_proration = (@bi_line_freight.charge_amount / BigDecimal.new("44"))
      l[:international_freight].should == (BigDecimal.new("100") + (global_freight_proration * ci_2_line_1.quantity)).round(2, BigDecimal::ROUND_HALF_UP)
      lc[:totals][:international_freight].should == BigDecimal.new("200")
    end

    context :landed_cost_data_for_entries do
      # Under the covers landed_cost_data_for_entries uses the exact same code as the one for the single entry, so just
      # validate that we get results we're expecting here

      it "should accept a string sql fragment and calculate landed cost for it" do
        lc = described_class.new.landed_cost_data_for_entries @entry.importer_id, "entries.customer_name = 'Test'"
        lc[:entries].should have(1).item
        lc[:entries].first[:broker_reference].should == @entry.broker_reference
      end

      it "should accept a sql fragment and calculate landed cost for it" do
        lc = described_class.new.landed_cost_data_for_entries @entry.importer_id, Entry.where(:customer_name => "Test")
        lc[:entries].should have(1).item
        lc[:entries].first[:broker_reference].should == @entry.broker_reference
      end
    end
  end
end
