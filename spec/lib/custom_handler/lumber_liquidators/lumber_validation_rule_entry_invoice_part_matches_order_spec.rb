require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberValidationRuleEntryInvoicePartMatchesOrder do
  before :each do
    @rule = OpenChain::CustomHandler::LumberLiquidators::LumberValidationRuleEntryInvoicePartMatchesOrder.new

    @ent = Factory(:entry)
    @ci = Factory(:commercial_invoice, invoice_number: "135A", entry: @ent)
    @cil = Factory(:commercial_invoice_line, commercial_invoice: @ci, line_number: 1, part_number: "123456", po_number: "654321")
    @prod = Factory(:product, unique_identifier: "123456")
    @ord = Factory(:order, order_number: "654321")
    @ol = Factory(:order_line, order: @ord, product: @prod )
    @bvre = Factory(:business_validation_result, validatable: @ord, state: "Pass")

    @order_hsh = {"order" => {"id" => @ord.id, "ord_rule_state" => "Pass", "ord_closed_at" => nil, "order_lines" => [{"id" => @ol.id, "ordln_puid" => "123456"}]} }
    @api_client_double = double("OrderApiClient")
    OpenChain::Api::OrderApiClient.should_receive(:new).with("ll").and_return @api_client_double
  end

  it "passes if every invoice line has a PO with a product that matches the line's part number" do
    @api_client_double.should_receive(:find_by_order_number).with(@cil.po_number, [:ord_rule_state, :ord_closed_at, :ordln_puid]).and_return @order_hsh

    expect(@rule.run_validation @ent).to be_nil
  end

  it "fails if any invoice line has a PO with a product that doesn't match the line's part number" do
    @api_client_double.should_receive(:find_by_order_number).with(@cil.po_number, [:ord_rule_state, :ord_closed_at, :ordln_puid]).and_return @order_hsh
    @cil.update_attributes(part_number: "foo")

    expect(@rule.run_validation @ent).to eq "The following invoices have POs that don't match their part numbers: 135A PO 654321 part foo\n\n"
  end

  it "fails if any invoice line doesn't have a PO" do
    @api_client_double.should_receive(:find_by_order_number).with(@cil.po_number, [:ord_rule_state, :ord_closed_at, :ordln_puid]).and_return({"order"=>nil})

    expect(@rule.run_validation @ent).to eq "The part number for the following invoices do not have a matching PO: 135A PO 654321 part 123456\n\n"
  end

  it "fails if any invoice is missing a part number" do
    @api_client_double.should_receive(:find_by_order_number).with(@cil.po_number, [:ord_rule_state, :ord_closed_at, :ordln_puid]).and_return @order_hsh
    @cil.update_attributes(part_number: nil)

    expect(@rule.run_validation @ent).to eq "The following invoices are missing a part number: 135A PO 654321\n\n"
  end

  it "fails if any invoice line has a PO with a failing business rule" do
    @order_hsh['order']['ord_rule_state'] = "Fail"
    @api_client_double.should_receive(:find_by_order_number).with(@cil.po_number, [:ord_rule_state, :ord_closed_at, :ordln_puid]).and_return @order_hsh

    expect(@rule.run_validation @ent).to eq "Purchase orders associated with the following invoices have a failing business rule: 135A PO 654321 part 123456\n\n"
  end

  it "fails if matching order is inactive" do
    @order_hsh['order']['ord_closed_at'] = '2016-01-01'
    @api_client_double.should_receive(:find_by_order_number).with(@cil.po_number, [:ord_rule_state, :ord_closed_at, :ordln_puid]).and_return @order_hsh

    expect(@rule.run_validation @ent).to eq "The following invoices have inactive purchase orders: 135A PO 654321 part 123456\n\n"    
  end


end