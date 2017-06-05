describe OpenChain::EntityCompare::ProductComparator::StaleTariffComparator do

  let (:country) { Factory(:country, iso_code: "CA") }
  let (:cdefs) { described_class.new.cdefs }
  let! (:valid_tariff) { OfficialTariff.create! hts_code: "1231890123", country_id: country.id }
  let! (:product) { 
    product = Factory(:product)
    c = product.classifications.create! country: country
    c.tariff_records.create! line_number: 1, hts_1: valid_tariff.hts_code

    product
  }

  def snapshot prod
    prod.reload
    ActiveSupport::JSON.decode(CoreModule::PRODUCT.entity_json prod)
  end

  def mark_classification_stale product
    c = product.classifications.first
    c.update_custom_value! cdefs[:class_stale_classification], true

    c
  end

  describe "check_for_unstale_tariffs" do
    let (:old_snapshot) { snapshot(product) }
    let (:new_snapshot) { snapshot(product) }

    before :each do
      product.classifications.first.tariff_records.first.update_attributes! hts_1: "1234567890"
      mark_classification_stale(product)
      old_snapshot

      product.classifications.first.tariff_records.first.update_attributes! hts_1: "1231890123"
      new_snapshot
    end

    it "identifies changed classification as not stale" do
      expect(subject).to receive(:get_json_hash).with("nb", "np", "nv").and_return new_snapshot
      expect(subject).to receive(:get_json_hash).with("ob", "op", "ov").and_return old_snapshot
      
      tariffs = subject.check_for_unstale_tariffs "ob", "op", "ov", "nb", "np", "nv"
      expect(tariffs).to eq({"CA" => ["1231890123"]})
    end

    it "does not return results if classification is still stale" do
      valid_tariff.destroy
      expect(subject).to receive(:get_json_hash).with("nb", "np", "nv").and_return new_snapshot
      expect(subject).to receive(:get_json_hash).with("ob", "op", "ov").and_return old_snapshot
      
      tariffs = subject.check_for_unstale_tariffs "ob", "op", "ov", "nb", "np", "nv"
      expect(tariffs).to be_blank
    end

    it "does not return results if one of a multi-classification product is still stale" do
      # Just create a random secondary tariff number that doesn't have an official tariff
      product.classifications.first.tariff_records.create! hts_1: "121823189"
      another_snapshot = snapshot(product)

      expect(subject).to receive(:get_json_hash).with("nb", "np", "nv").and_return another_snapshot
      expect(subject).to receive(:get_json_hash).with("ob", "op", "ov").and_return old_snapshot

      tariffs = subject.check_for_unstale_tariffs "ob", "op", "ov", "nb", "np", "nv"
      expect(tariffs).to be_blank
    end

    it "returns results if all tariffs are valid" do
      # Just create a random secondary tariff number that doesn't have an official tariff
      product.classifications.first.tariff_records.create! hts_1: "121823189"
      OfficialTariff.create! country: country, hts_code: "121823189"
      another_snapshot = snapshot(product)

      expect(subject).to receive(:get_json_hash).with("nb", "np", "nv").and_return another_snapshot
      expect(subject).to receive(:get_json_hash).with("ob", "op", "ov").and_return old_snapshot

      tariffs = subject.check_for_unstale_tariffs "ob", "op", "ov", "nb", "np", "nv"
      expect(tariffs).to eq({"CA" => ["1231890123", "121823189"]})
    end

    it "does not return results if classification is not marked as stale in snapshot" do
      product.classifications.first.update_custom_value! cdefs[:class_stale_classification], nil
      another_snapshot = snapshot(product)

      expect(subject).to receive(:get_json_hash).with("nb", "np", "nv").and_return another_snapshot
      expect(subject).not_to receive(:get_json_hash).with("ob", "op", "ov")

      tariffs = subject.check_for_unstale_tariffs "ob", "op", "ov", "nb", "np", "nv"
      expect(tariffs).to be_blank
    end
  end

  describe "check_for_stale_tariffs" do
    let (:new_snapshot) { snapshot(product) }

    it "checks that all classifications have valid tariffs, returns blank if they do" do
      expect(subject).to receive(:get_json_hash).with("nb", "np", "nv").and_return new_snapshot

      tariffs = subject.check_for_stale_tariffs "nb", "np", "nv"
      expect(tariffs).to be_blank
    end

    it "returns all hts for a tariff when one is stale" do
      product.classifications.first.tariff_records.create! hts_1: "121823189"

      expect(subject).to receive(:get_json_hash).with("nb", "np", "nv").and_return new_snapshot

      tariffs = subject.check_for_stale_tariffs "nb", "np", "nv"
      expect(tariffs).to eq({"CA" => ["1231890123", "121823189"]})
    end

    it "does not return anything if the classification is already marked stale" do
      product.classifications.first.tariff_records.create! hts_1: "121823189"
      mark_classification_stale(product)

      expect(subject).to receive(:get_json_hash).with("nb", "np", "nv").and_return snapshot(product)

      tariffs = subject.check_for_stale_tariffs "nb", "np", "nv"
      expect(tariffs).to be_blank
    end
  end

  describe "update_product" do
    it "sets classification as not stale if instructed" do
      mark_classification_stale(product)

      subject.update_product product.id, {"CA" => ["1231890123"]}, {}

      product.reload
      expect(product.classifications.first.custom_value(cdefs[:class_stale_classification])).to be_nil
      expect(product.entity_snapshots.length).to eq 1
      expect(product.entity_snapshots.first.context).to eq "Stale Tariff Detector"
    end

    it "does not update classification to stale if product has a different tariff" do
      mark_classification_stale(product)

      subject.update_product product.id, {"CA" => ["91239019012"]}, {}

      product.reload
      expect(product.classifications.first.custom_value(cdefs[:class_stale_classification])).to eq true
    end

    it "does not update classification to stale if product has a different set of tariffs" do
      mark_classification_stale(product)

      subject.update_product product.id, {"CA" => ["1231890123", "91239019012"]}, {}

      product.reload
      expect(product.classifications.first.custom_value(cdefs[:class_stale_classification])).to eq true
    end

    it "sets classification to stale if instructed" do
      subject.update_product product.id, {}, {"CA" => ["1231890123"]}

      product.reload
      expect(product.classifications.first.custom_value(cdefs[:class_stale_classification])).to eq true
      expect(product.entity_snapshots.length).to eq 1
      expect(product.entity_snapshots.first.context).to eq "Stale Tariff Detector"
    end

    it "does not set classification to stale if product has a different tariff" do
      subject.update_product product.id, {}, {"CA" => ["91239019012"]}

      product.reload
      expect(product.classifications.first.custom_value(cdefs[:class_stale_classification])).to be_nil
    end

    it "does not set classification to stale if product has a different set of tariffs" do
      subject.update_product product.id, {}, {"CA" => ["1231890123", "91239019012"]}

      product.reload
      expect(product.classifications.first.custom_value(cdefs[:class_stale_classification])).to be_nil
    end
  end
end