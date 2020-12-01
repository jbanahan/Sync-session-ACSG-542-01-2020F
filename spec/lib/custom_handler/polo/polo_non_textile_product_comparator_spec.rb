describe OpenChain::CustomHandler::Polo::PoloNonTextileProductComparator do

  describe "compare" do
    subject { described_class }
    let (:cdefs) { subject.new.cdefs }
    let (:product) { FactoryBot(:product) }

    it "sets Non Textile flag to N when knit woven field = KNIT" do
      product.update_custom_value! cdefs[:knit_woven], "KnIt"

      subject.compare(nil, product.id, nil, nil, nil, nil, nil, nil)

      product.reload
      expect(product.custom_value(cdefs[:non_textile])).to eq "N"
      expect(product).to have_snapshot(User.integration, "Non Textile Product Comparator")
    end

    it "sets Non Textile flag to N when knit woven field = KNIT" do
      product.update_custom_value! cdefs[:knit_woven], "WoVeN"

      subject.compare(nil, product.id, nil, nil, nil, nil, nil, nil)

      product.reload
      expect(product.custom_value(cdefs[:non_textile])).to eq "N"
      expect(product).to have_snapshot(User.integration, "Non Textile Product Comparator")
    end

    it "sets the Non Textile flag to Y for any other value" do
      product.update_custom_value! cdefs[:knit_woven], ""

      subject.compare(nil, product.id, nil, nil, nil, nil, nil, nil)

      product.reload
      expect(product.custom_value(cdefs[:non_textile])).to eq "Y"
      expect(product).to have_snapshot(User.integration, "Non Textile Product Comparator")
    end

    it "does nothing if the non-textile value is unchanged" do
      product.update_custom_value! cdefs[:knit_woven], "WoVeN"
      product.update_custom_value! cdefs[:non_textile], "N"

      subject.compare(nil, product.id, nil, nil, nil, nil, nil, nil)

      product.reload
      expect(product).not_to have_a_snapshot
    end
  end
end