describe FingerprintSupport do

  describe "generate_fingerprint" do
    let (:product) { FactoryBot(:tariff_record, hts_1: "9876543210", hts_2: "1234567890").product }

    let (:fingerprint_definition) {
      {model_fields: [:prod_uid],
       classifications: {
          model_fields: [:class_cntry_iso],
          tariff_records: {
            model_fields: [:hts_hts_1, :hts_hts_2]
          }
        }
      }
    }

    let (:user) { FactoryBot(:user) }

    it "generates a SHA-1 hexdigest fingerprint based on the given data fields for a CoreModule object" do
      fingerprint = product.generate_fingerprint fingerprint_definition, user
      expect(fingerprint).not_to be_nil
    end

    it "generates the same fingerprint even if a non-fingerprinted field value has been changed since the first call" do
      fingerprint = product.generate_fingerprint fingerprint_definition, user
      product.update_attributes! name: "Testing123"
      expect(product.generate_fingerprint fingerprint_definition, user).to eq fingerprint
    end

    it "generates different fingerprints if a fingerprinted field changes" do
      fingerprint = product.generate_fingerprint fingerprint_definition, user
      product.update_attributes! unique_identifier: "Testing123"
      expect(product.generate_fingerprint fingerprint_definition, user).not_to eq fingerprint
    end

    it "generates different fingerprints if a fingerprinted child record has been changed" do
      fingerprint = product.generate_fingerprint fingerprint_definition, user
      product.classifications.first.country = FactoryBot(:country)
      expect(product.generate_fingerprint fingerprint_definition, user).not_to eq fingerprint
    end

    it "generates different fingerprints if a fingerprinted grandchild record has been changed" do
      fingerprint = product.generate_fingerprint fingerprint_definition, user
      product.classifications.first.tariff_records.first.update_attributes! hts_1: "8012381289"
      expect(product.generate_fingerprint fingerprint_definition, user).not_to eq fingerprint
    end

    it "generates different fingerprints if a new child record is added" do
      fingerprint = product.generate_fingerprint fingerprint_definition, user
      product.classifications << FactoryBot(:classification)
      expect(product.generate_fingerprint fingerprint_definition, user).not_to eq fingerprint
    end

    it "generates different fingerprints if a new grandchild record is added" do
      fingerprint = product.generate_fingerprint fingerprint_definition, user
      product.classifications.first.tariff_records.create! line_number: 2, hts_1: "1238901231908"
      expect(product.generate_fingerprint fingerprint_definition, user).not_to eq fingerprint
    end

    it "does not generate a different fingerprint if a record is deleted and a new identical record is added in place" do
      # This mimics the situation where we do something like delete child records and then recreate them from 3rd party data - which is
      # something we do fairly often in parsers and a situation where it can be critical that the same fingerprint is
      # generated even if the objects are totally different
      fingerprint = product.generate_fingerprint fingerprint_definition, user
      c = product.classifications.first
      tr = c.tariff_records.first
      product.classifications.destroy_all
      product.classifications.create! country: c.country

      product.classifications.first.tariff_records.create! hts_1: tr.hts_1, hts_2: tr.hts_2
      expect(product.generate_fingerprint fingerprint_definition, user).to eq fingerprint
    end

    it "generates a different fingerprint if the fingerprint field definition is changed, even if no data exists in the object for the field added" do
      fingerprint = product.generate_fingerprint fingerprint_definition, user
      fingerprint_definition[:model_fields] << :prod_name
      expect(product.generate_fingerprint fingerprint_definition, user).not_to eq fingerprint
    end

    it "skips child objects that are marked for destruction" do
      fingerprint = product.generate_fingerprint fingerprint_definition, user
      product.classifications.first.mark_for_destruction
      updated_fingerprint = product.generate_fingerprint fingerprint_definition, user

      expect(fingerprint).not_to eq updated_fingerprint
    end
  end

end