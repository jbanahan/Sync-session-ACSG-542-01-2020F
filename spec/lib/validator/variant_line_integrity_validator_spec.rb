require 'spec_helper'

describe OpenChain::Validator::VariantLineIntegrityValidator do
  it "should allow product that matches variant" do
    ol = OrderLine.new
    p = Product.new(id:100)
    ol.product = p
    ol.variant = Variant.new(product:p)
    described_class.new(attributes:{}).validate(ol)
    expect(ol.errors.size).to eq 0
  end
  it "should not allow product with different variant" do
    ol = OrderLine.new
    p = Product.new(id:100)
    ol.product = p
    ol.variant = Variant.new(product:Product.new(id:101))
    described_class.new(attributes:{}).validate(ol)
    expect(ol.errors.size).to eq 1
    expect(ol.errors[:variant].first).to match(/must be associated with same product/)
  end
  it "should allow no variant" do
    ol = OrderLine.new
    p = Product.new(id:100)
    ol.product = p
    described_class.new(attributes:{}).validate(ol)
    expect(ol.errors.size).to eq 0
  end
end
