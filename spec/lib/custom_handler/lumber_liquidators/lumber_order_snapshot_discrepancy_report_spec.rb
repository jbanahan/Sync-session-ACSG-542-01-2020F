require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberOrderSnapshotDiscrepancyReport do

  describe "permission?" do
    let(:ms) { stub_master_setup }
    let(:user) { double(:user) }

    it "grants permission to users that can view orders and who belong to 'Lumber Liquidators'" do
      expect(ms).to receive(:custom_feature?).with("Lumber Liquidators").and_return(true)
      expect(user).to receive(:view_orders?).and_return(true)
      expect(described_class.permission? user).to eq true
    end

    it "grants permission to users that can view shipments and who belong to 'Lumber Liquidators'" do
      expect(ms).to receive(:custom_feature?).with("Lumber Liquidators").and_return(true)
      expect(user).to receive(:view_orders?).and_return(false)
      expect(user).to receive(:view_shipments?).and_return(true)
      expect(described_class.permission? user).to eq true
    end

    it "restricts access from users that cannot view orders or shipments, even though they belong to 'Lumber Liquidators'" do
      expect(ms).to receive(:custom_feature?).with("Lumber Liquidators").and_return(true)
      expect(user).to receive(:view_orders?).and_return(false)
      expect(user).to receive(:view_shipments?).and_return(false)
      expect(described_class.permission? user).to eq false
    end

    it "restricts access from users that do not belong to 'Lumber Liquidators'" do
      expect(ms).to receive(:custom_feature?).with("Lumber Liquidators").and_return(false)
      expect(described_class.permission? user).to eq false
    end
  end

  describe "run_report" do
    before :each do
      @cdefs = described_class.prep_custom_definitions [:ordln_po_create_article,:ordln_po_create_quantity,:ordln_po_create_hts,:ordln_po_create_price_per_unit,:ordln_po_create_total_price,:ordln_po_create_country_origin,:ordln_po_booked_article,:ordln_po_booked_quantity,:ordln_po_booked_hts,:ordln_po_booked_price_per_unit,:ordln_po_booked_total_price,:ordln_po_booked_country_origin,:ordln_po_shipped_article,:ordln_po_shipped_quantity,:ordln_po_shipped_hts,:ordln_po_shipped_price_per_unit,:ordln_po_shipped_total_price,:ordln_po_shipped_country_origin,:ord_snapshot_discrepancy_comment]
      ms = stub_master_setup
      allow(ms).to receive(:request_host).and_return('some_host')
    end

    def set_snapshot_value_and_date ol, cdef_ref, value, date
      # Timecop freeze is involved because the snapshot dates used for filtration and such are really just
      # the 'updated_at' values of the custom values.
      Timecop.freeze(date) do
        ol.update_custom_value! @cdefs[cdef_ref], value
      end
    end

    after :each do
      @tempfile.close! if @tempfile && !@tempfile.closed?
    end

    it "runs report based on snapshot date filters" do
      vendor = Factory(:company, name:'Crudco')
      order_1 = Factory(:order, order_number: '5551234', vendor:vendor, created_at:DateTime.new(2018,3,31))
      order_1.update_custom_value! @cdefs[:ord_snapshot_discrepancy_comment], "This order is discrepant.\nIt's discrepanting."

      prod = Factory(:product)
      ol_1 = order_1.order_lines.create! line_number: 1, product:prod
      set_snapshot_value_and_date ol_1, :ordln_po_create_article, "Article 1", DateTime.new(2018,1,11)
      set_snapshot_value_and_date ol_1, :ordln_po_booked_article, "Article 1", DateTime.new(2018,1,13)
      set_snapshot_value_and_date ol_1, :ordln_po_shipped_article, "Article 2", DateTime.new(2018,1,15)

      set_snapshot_value_and_date ol_1, :ordln_po_create_quantity, 10.5, DateTime.new(2018,1,12)
      set_snapshot_value_and_date ol_1, :ordln_po_booked_quantity, 2.5, DateTime.new(2018,1,14)
      set_snapshot_value_and_date ol_1, :ordln_po_shipped_quantity, 10.5, DateTime.new(2018,1,16)

      set_snapshot_value_and_date ol_1, :ordln_po_create_hts, "HTS 1", DateTime.new(2018,1,11)
      set_snapshot_value_and_date ol_1, :ordln_po_booked_hts, "HTS 2", DateTime.new(2018,1,13)
      set_snapshot_value_and_date ol_1, :ordln_po_shipped_hts, "HTS 2", DateTime.new(2018,1,15)

      set_snapshot_value_and_date ol_1, :ordln_po_create_price_per_unit, 11.25, DateTime.new(2018,1,11)
      set_snapshot_value_and_date ol_1, :ordln_po_booked_price_per_unit, 12.5, DateTime.new(2018,1,12)
      set_snapshot_value_and_date ol_1, :ordln_po_shipped_price_per_unit, 13.75, DateTime.new(2018,1,13)

      set_snapshot_value_and_date ol_1, :ordln_po_create_total_price, 21.25, DateTime.new(2018,1,13)
      set_snapshot_value_and_date ol_1, :ordln_po_booked_total_price, 22.5, DateTime.new(2018,1,14)
      set_snapshot_value_and_date ol_1, :ordln_po_shipped_total_price, 23.75, DateTime.new(2018,1,15)

      set_snapshot_value_and_date ol_1, :ordln_po_create_country_origin, "Wakanda", DateTime.new(2018,1,11)
      set_snapshot_value_and_date ol_1, :ordln_po_booked_country_origin, "Wakanda", DateTime.new(2018,1,14)
      set_snapshot_value_and_date ol_1, :ordln_po_shipped_country_origin, "Sokovia", DateTime.new(2018,1,15)

      ol_2 = order_1.order_lines.create! line_number: 2, product:prod
      set_snapshot_value_and_date ol_2, :ordln_po_create_article, "Article 2", DateTime.new(2018,1,11)
      set_snapshot_value_and_date ol_2, :ordln_po_booked_article, "Article 3", DateTime.new(2018,1,14)

      # These ones don't change, so this should not be shown on the report.
      set_snapshot_value_and_date ol_2, :ordln_po_create_quantity, 10.5, DateTime.new(2018,1,12)
      set_snapshot_value_and_date ol_2, :ordln_po_booked_quantity, 10.5, DateTime.new(2018,1,14)

      shp = Factory(:shipment, booking_received_date:DateTime.new(2018,1,10), departure_date:DateTime.new(2018,1,12))
      shp.booking_lines.create! order_line:order_1.order_lines[0]

      order_2 = Factory(:order, order_number: '5551235', vendor:vendor, created_at:DateTime.new(2018,3,25))
      order_2.update_custom_value! @cdefs[:ord_snapshot_discrepancy_comment], "This order is also discrepant."
      ol_3 = order_2.order_lines.create! line_number: 3, product:prod

      # Should be sorted above the other PO because it has an earlier snapshot date.  Accepted even though the
      # earliest snapshot date is before the report range because the "actual" snapshot date, for shipped, is within
      # the range.
      set_snapshot_value_and_date ol_3, :ordln_po_create_total_price, 31.25, DateTime.new(2018,12,31)
      set_snapshot_value_and_date ol_3, :ordln_po_booked_total_price, 32.5, DateTime.new(2018,1,2)
      set_snapshot_value_and_date ol_3, :ordln_po_shipped_total_price, 33.75, DateTime.new(2018,1,5)

      order_3 = Factory(:order, order_number: '5551236', vendor:vendor, created_at:DateTime.new(2018,3,27))
      ol_4 = order_3.order_lines.create! line_number: 4, product:prod

      # Should be excluded because the snapshot dates all occur before the date range.
      set_snapshot_value_and_date ol_4, :ordln_po_create_total_price, 31.25, DateTime.new(2017,12,25)
      set_snapshot_value_and_date ol_4, :ordln_po_booked_total_price, 32.5, DateTime.new(2017,12,26)
      set_snapshot_value_and_date ol_4, :ordln_po_shipped_total_price, 33.75, DateTime.new(2017,12,27)

      order_4 = Factory(:order, order_number: '5551237', vendor:vendor, created_at:DateTime.new(2018,3,28))
      ol_5 = order_4.order_lines.create! line_number: 5, product:prod

      # Should be excluded because the snapshot dates all occur after the date range.
      set_snapshot_value_and_date ol_5, :ordln_po_create_total_price, 31.25, DateTime.new(2018,2,1)
      set_snapshot_value_and_date ol_5, :ordln_po_booked_total_price, 32.5, DateTime.new(2018,2,2)
      set_snapshot_value_and_date ol_5, :ordln_po_shipped_total_price, 33.75, DateTime.new(2018,2,3)

      order_5 = Factory(:order, order_number: '5551238', vendor:vendor, created_at:DateTime.new(2018,3,29))
      ol_6 = order_5.order_lines.create! line_number: 5, product:prod

      # Should be excluded because the highest snapshot date is outside the date range.
      set_snapshot_value_and_date ol_6, :ordln_po_create_total_price, 31.25, DateTime.new(2018,1,25)
      set_snapshot_value_and_date ol_6, :ordln_po_booked_total_price, 32.5, DateTime.new(2018,1,30)
      set_snapshot_value_and_date ol_6, :ordln_po_shipped_total_price, 33.75, DateTime.new(2018,2,2)

      args = { 'open_orders_only'=>false, 'snapshot_range_start_date'=>'2018-01-01', 'snapshot_range_end_date'=>'2018-01-31' }
      @tempfile = described_class.run_report nil, args
      expect(@tempfile.path).to include "LumberOrderSnapshotDiscrepancy"
      expect(@tempfile.path).to end_with ".xls"

      wb = Spreadsheet.open(@tempfile.path)
      sheet = wb.worksheets.first
      expect(sheet.name).to eq "Discrepancies"

      expect(sheet.rows.length).to eq 10
      expect(sheet.row(0)).to eq ["PO", "Order Line", "Vendor", "PO Create Date", "Booking Requested Date", "Shipment Date", "Entry Date", "Goods Receipt Date", "Snapshot Date", "Snapshot Discrepancy Comments", "Field", "PO Creation", "Booking Requested", "Shipment", "Entry", "Goods Receipt"]

      expect(sheet.row(1)[0]).to be_an_instance_of Spreadsheet::Link
      expect(sheet.row(1)[0].href).to include "some_host", "orders", order_2.id.to_s
      expect(sheet.row(1)[0].to_s).to eq "5551235"
      expect(sheet.row(1)[1]).to eq 3
      expect(sheet.row(1)[2]).to eq "Crudco"
      expect(sheet.row(1)[3]).to eq DateTime.new(2018,3,25)
      # Not connected to a shipment, so no shipment dates.
      expect(sheet.row(1)[4]).to be_nil
      expect(sheet.row(1)[5]).to be_nil
      expect(sheet.row(1)[6]).to be_nil
      expect(sheet.row(1)[7]).to be_nil
      expect(sheet.row(1)[8]).to eq DateTime.new(2018,1,5)
      expect(sheet.row(1)[9]).to eq "This order is also discrepant."
      expect(sheet.row(1)[10]).to eq "Total Price"
      expect(sheet.row(1)[11]).to eq 31.25
      expect(sheet.row(1)[12]).to eq 32.5
      expect(sheet.row(1)[13]).to eq 33.75
      expect(sheet.row(1)[14]).to be_nil
      expect(sheet.row(1)[15]).to be_nil

      # Blank spacer row.
      expect(sheet.row(2)[0]).to be_nil
      expect(sheet.row(2)[1]).to be_nil

      expect(sheet.row(3)[0]).to be_an_instance_of Spreadsheet::Link
      expect(sheet.row(3)[0].href).to include "some_host", "orders", order_1.id.to_s
      expect(sheet.row(3)[0].to_s).to eq "5551234"
      expect(sheet.row(3)[1]).to eq 1
      expect(sheet.row(3)[2]).to eq "Crudco"
      expect(sheet.row(3)[3]).to eq DateTime.new(2018,3,31)
      expect(sheet.row(3)[4]).to eq DateTime.new(2018,1,10)
      expect(sheet.row(3)[5]).to eq DateTime.new(2018,1,12)
      expect(sheet.row(3)[6]).to be_nil
      expect(sheet.row(3)[7]).to be_nil
      expect(sheet.row(3)[8]).to eq DateTime.new(2018,1,15)
      expect(sheet.row(3)[9]).to eq "This order is discrepant.\nIt's discrepanting."
      expect(sheet.row(3)[10]).to eq "Article"
      expect(sheet.row(3)[11]).to eq "Article 1"
      expect(sheet.row(3)[12]).to eq "Article 1"
      expect(sheet.row(3)[13]).to eq "Article 2"
      expect(sheet.row(3)[14]).to be_nil
      expect(sheet.row(3)[15]).to be_nil

      expect(sheet.row(4)[0].to_s).to eq "5551234"
      expect(sheet.row(4)[1]).to eq 1
      expect(sheet.row(4)[8]).to eq DateTime.new(2018,1,16)
      expect(sheet.row(4)[10]).to eq "Quantity"
      expect(sheet.row(4)[11]).to eq 10.5
      expect(sheet.row(4)[12]).to eq 2.5
      expect(sheet.row(4)[13]).to eq 10.5

      expect(sheet.row(5)[0].to_s).to eq "5551234"
      expect(sheet.row(5)[1]).to eq 1
      expect(sheet.row(5)[8]).to eq DateTime.new(2018,1,15)
      expect(sheet.row(5)[10]).to eq "HTS"
      expect(sheet.row(5)[11]).to eq "HTS 1"
      expect(sheet.row(5)[12]).to eq "HTS 2"
      expect(sheet.row(5)[13]).to eq "HTS 2"

      expect(sheet.row(6)[0].to_s).to eq "5551234"
      expect(sheet.row(6)[1]).to eq 1
      expect(sheet.row(6)[8]).to eq DateTime.new(2018,1,13)
      expect(sheet.row(6)[10]).to eq "Price/Unit"
      expect(sheet.row(6)[11]).to eq 11.25
      expect(sheet.row(6)[12]).to eq 12.5
      expect(sheet.row(6)[13]).to eq 13.75

      expect(sheet.row(7)[0].to_s).to eq "5551234"
      expect(sheet.row(7)[1]).to eq 1
      expect(sheet.row(7)[8]).to eq DateTime.new(2018,1,15)
      expect(sheet.row(7)[10]).to eq "Total Price"
      expect(sheet.row(7)[11]).to eq 21.25
      expect(sheet.row(7)[12]).to eq 22.5
      expect(sheet.row(7)[13]).to eq 23.75

      expect(sheet.row(8)[0].to_s).to eq "5551234"
      expect(sheet.row(8)[1]).to eq 1
      expect(sheet.row(8)[8]).to eq DateTime.new(2018,1,15)
      expect(sheet.row(8)[10]).to eq "Country of Origin"
      expect(sheet.row(8)[11]).to eq "Wakanda"
      expect(sheet.row(8)[12]).to eq "Wakanda"
      expect(sheet.row(8)[13]).to eq "Sokovia"

      expect(sheet.row(9)[0].to_s).to eq "5551234"
      expect(sheet.row(9)[1]).to eq 2
      # No shipment attached to this line, but it gets shipment info because it's lumped in with the other order line.
      # Situation probably wouldn't occur in practice.
      expect(sheet.row(9)[4]).to eq DateTime.new(2018,1,10)
      expect(sheet.row(9)[5]).to eq DateTime.new(2018,1,12)
      expect(sheet.row(9)[8]).to eq DateTime.new(2018,1,14)
      expect(sheet.row(9)[10]).to eq "Article"
      expect(sheet.row(9)[11]).to eq "Article 2"
      expect(sheet.row(9)[12]).to eq "Article 3"
    end

    it "runs report based on snapshot date filters with null values" do
      vendor = Factory(:company, name:'Crudco')
      order_1 = Factory(:order, order_number: '5551234', vendor:vendor, created_at:DateTime.new(2018,3,31))

      prod = Factory(:product)
      ol_1 = order_1.order_lines.create! line_number: 1, product:prod
      set_snapshot_value_and_date ol_1, :ordln_po_create_article, "Article 1", DateTime.new(2018,1,11)
      set_snapshot_value_and_date ol_1, :ordln_po_booked_article, "Article 1", DateTime.new(2018,1,13)
      set_snapshot_value_and_date ol_1, :ordln_po_shipped_article, nil, DateTime.new(2018,1,15)

      set_snapshot_value_and_date ol_1, :ordln_po_create_quantity, 10.5, DateTime.new(2018,1,12)
      set_snapshot_value_and_date ol_1, :ordln_po_booked_quantity, nil, DateTime.new(2018,1,14)
      set_snapshot_value_and_date ol_1, :ordln_po_shipped_quantity, 10.5, DateTime.new(2018,1,16)

      set_snapshot_value_and_date ol_1, :ordln_po_create_hts, nil, DateTime.new(2018,1,11)
      set_snapshot_value_and_date ol_1, :ordln_po_booked_hts, "HTS 2", DateTime.new(2018,1,13)
      set_snapshot_value_and_date ol_1, :ordln_po_shipped_hts, "HTS 2", DateTime.new(2018,1,15)

      set_snapshot_value_and_date ol_1, :ordln_po_create_price_per_unit, 11.25, DateTime.new(2018,1,11)
      set_snapshot_value_and_date ol_1, :ordln_po_booked_price_per_unit, 12.5, DateTime.new(2018,1,12)
      set_snapshot_value_and_date ol_1, :ordln_po_shipped_price_per_unit, nil, DateTime.new(2018,1,13)

      set_snapshot_value_and_date ol_1, :ordln_po_create_total_price, nil, DateTime.new(2018,1,13)
      set_snapshot_value_and_date ol_1, :ordln_po_booked_total_price, nil, DateTime.new(2018,1,14)
      set_snapshot_value_and_date ol_1, :ordln_po_shipped_total_price, 23.75, DateTime.new(2018,1,15)

      set_snapshot_value_and_date ol_1, :ordln_po_create_country_origin, "Wakanda", DateTime.new(2018,1,11)
      set_snapshot_value_and_date ol_1, :ordln_po_booked_country_origin, "Wakanda", DateTime.new(2018,1,14)
      set_snapshot_value_and_date ol_1, :ordln_po_shipped_country_origin, nil, DateTime.new(2018,1,15)

      ol_2 = order_1.order_lines.create! line_number: 2, product:prod
      set_snapshot_value_and_date ol_2, :ordln_po_create_article, "Article 2", DateTime.new(2018,1,11)
      set_snapshot_value_and_date ol_2, :ordln_po_booked_article, nil, DateTime.new(2018,1,14)

      # These ones don't change, so this should not be shown on the report.
      set_snapshot_value_and_date ol_2, :ordln_po_create_quantity, nil, DateTime.new(2018,1,12)
      set_snapshot_value_and_date ol_2, :ordln_po_booked_quantity, nil, DateTime.new(2018,1,14)

      args = { 'open_orders_only'=>false, 'snapshot_range_start_date'=>'2018-01-01', 'snapshot_range_end_date'=>'2018-01-31' }
      @tempfile = described_class.run_report nil, args
      expect(@tempfile.path).to include "LumberOrderSnapshotDiscrepancy"
      expect(@tempfile.path).to end_with ".xls"

      wb = Spreadsheet.open(@tempfile.path)
      sheet = wb.worksheets.first
      expect(sheet.name).to eq "Discrepancies"

      expect(sheet.rows.length).to eq 8
      expect(sheet.row(0)).to eq ["PO", "Order Line", "Vendor", "PO Create Date", "Booking Requested Date", "Shipment Date", "Entry Date", "Goods Receipt Date", "Snapshot Date", "Snapshot Discrepancy Comments", "Field", "PO Creation", "Booking Requested", "Shipment", "Entry", "Goods Receipt"]

      expect(sheet.row(1)[1]).to eq 1
      expect(sheet.row(1)[8]).to eq DateTime.new(2018,1,15)
      expect(sheet.row(1)[10]).to eq "Article"
      expect(sheet.row(1)[11]).to eq "Article 1"
      expect(sheet.row(1)[12]).to eq "Article 1"
      expect(sheet.row(1)[13]).to be_nil
      expect(sheet.row(1)[14]).to be_nil
      expect(sheet.row(1)[15]).to be_nil

      expect(sheet.row(2)[1]).to eq 1
      expect(sheet.row(2)[8]).to eq DateTime.new(2018,1,16)
      expect(sheet.row(2)[10]).to eq "Quantity"
      expect(sheet.row(2)[11]).to eq 10.5
      expect(sheet.row(2)[12]).to be_nil
      expect(sheet.row(2)[13]).to eq 10.5

      expect(sheet.row(3)[1]).to eq 1
      expect(sheet.row(3)[8]).to eq DateTime.new(2018,1,15)
      expect(sheet.row(3)[10]).to eq "HTS"
      expect(sheet.row(3)[11]).to be_nil
      expect(sheet.row(3)[12]).to eq "HTS 2"
      expect(sheet.row(3)[13]).to eq "HTS 2"

      expect(sheet.row(4)[1]).to eq 1
      expect(sheet.row(4)[8]).to eq DateTime.new(2018,1,13)
      expect(sheet.row(4)[10]).to eq "Price/Unit"
      expect(sheet.row(4)[11]).to eq 11.25
      expect(sheet.row(4)[12]).to eq 12.5
      expect(sheet.row(4)[13]).to be_nil

      expect(sheet.row(5)[1]).to eq 1
      expect(sheet.row(5)[8]).to eq DateTime.new(2018,1,15)
      expect(sheet.row(5)[10]).to eq "Total Price"
      expect(sheet.row(5)[11]).to be_nil
      expect(sheet.row(5)[12]).to be_nil
      expect(sheet.row(5)[13]).to eq 23.75

      expect(sheet.row(6)[1]).to eq 1
      expect(sheet.row(6)[8]).to eq DateTime.new(2018,1,15)
      expect(sheet.row(6)[10]).to eq "Country of Origin"
      expect(sheet.row(6)[11]).to eq "Wakanda"
      expect(sheet.row(6)[12]).to eq "Wakanda"
      expect(sheet.row(6)[13]).to be_nil

      expect(sheet.row(7)[1]).to eq 2
      expect(sheet.row(7)[8]).to eq DateTime.new(2018,1,14)
      expect(sheet.row(7)[10]).to eq "Article"
      expect(sheet.row(7)[11]).to eq "Article 2"
      expect(sheet.row(7)[12]).to be_nil
    end

    it "runs report for open orders only" do
      vendor = Factory(:company, name:'Crudco')
      order_1 = Factory(:order, order_number: '5551234', vendor:vendor)

      prod = Factory(:product)
      ol_1 = order_1.order_lines.create! line_number: 1, product:prod
      set_snapshot_value_and_date ol_1, :ordln_po_create_article, "Article 1", DateTime.new(2018,1,11)
      set_snapshot_value_and_date ol_1, :ordln_po_booked_article, "Article 1", DateTime.new(2018,1,13)
      set_snapshot_value_and_date ol_1, :ordln_po_shipped_article, "Article 2", DateTime.new(2018,1,15)

      order_2 = Factory(:order, order_number: '5551235', vendor:vendor, closed_at: DateTime.new(2018,5,2))
      ol_2 = order_2.order_lines.create! line_number: 2, product:prod

      # This would normally show, but the order has been marked closed.  It is excluded.
      set_snapshot_value_and_date ol_2, :ordln_po_create_total_price, 31.25, DateTime.new(2018,1,3)
      set_snapshot_value_and_date ol_2, :ordln_po_booked_total_price, 32.5, DateTime.new(2018,1,4)
      set_snapshot_value_and_date ol_2, :ordln_po_shipped_total_price, 33.75, DateTime.new(2018,1,5)

      args = { 'open_orders_only'=>true }
      @tempfile = described_class.run_report nil, args
      expect(@tempfile.path).to include "LumberOrderSnapshotDiscrepancy"
      expect(@tempfile.path).to end_with ".xls"

      wb = Spreadsheet.open(@tempfile.path)
      sheet = wb.worksheets.first

      expect(sheet.rows.length).to eq 2
      expect(sheet.row(0)[0]).to eq "PO"

      expect(sheet.row(1)[0]).to eq "5551234"
      expect(sheet.row(1)[1]).to eq 1
      expect(sheet.row(1)[10]).to eq "Article"
      expect(sheet.row(1)[11]).to eq "Article 1"
      expect(sheet.row(1)[12]).to eq "Article 1"
      expect(sheet.row(1)[13]).to eq "Article 2"
    end
  end

end