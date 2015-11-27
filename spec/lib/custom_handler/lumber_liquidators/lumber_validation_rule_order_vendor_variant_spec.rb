require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberValidationRuleOrderVendorVariant do
  before :each do
    @cdefs = described_class.prep_custom_definitions [:pva_pc_approved_date]
    @vendor = Factory(:vendor,name:'MYVEND')
    @plant = Factory(:plant,company:@vendor)
    @plant2 = Factory(:plant,company:@vendor)

    @product1 = Factory(:product)
    @variant1 = Factory(:variant,product:@product1)

    @product2 = Factory(:product, unique_identifier:'PRODNUM2')
    @variant2 = Factory(:variant,product:@product2)

    @order = Factory(:order,vendor:@vendor)
    @order_line_1 = Factory(:order_line,product:@product1,order:@order)
    @order_line_2 = Factory(:order_line,product:@product2,order:@order)
  end
  it "should pass if all order lines have an product with an approved plant variant assignment for one of the vendor's plants" do
    pva1 = @variant1.plant_variant_assignments.create!(plant_id:@plant.id)
    pva2 = @variant2.plant_variant_assignments.create!(plant_id:@plant.id)
    [pva1,pva2].each {|pva| pva.update_custom_value!(@cdefs[:pva_pc_approved_date],Time.now)}

    @order.reload

    expect(described_class.new.run_validation(@order)).to be_nil
  end
  it "should fail if one of the order lines does not have a plant variant assignment for one of the vendors plants" do
    pva1 = @variant1.plant_variant_assignments.create!(plant_id:@plant.id)
    pva1.update_custom_value!(@cdefs[:pva_pc_approved_date],Time.now)

    @order.reload

    fail_messages = described_class.new.run_validation(@order)
    expect(fail_messages).to eq 'Product "PRODNUM2" does not have a variant assigned to vendor "MYVEND".'
  end
  it "should fail if one of the order lines has a plant variant assignment but it is not approved" do
    pva1 = @variant1.plant_variant_assignments.create!(plant_id:@plant.id)
    pva1.update_custom_value!(@cdefs[:pva_pc_approved_date],Time.now)

    @variant2.plant_variant_assignments.create!(plant_id:@plant.id)

    @order.reload

    fail_messages = described_class.new.run_validation(@order)

    expect(fail_messages).to eq 'Product "PRODNUM2" does not have an approved variant for "MYVEND".'
  end
end