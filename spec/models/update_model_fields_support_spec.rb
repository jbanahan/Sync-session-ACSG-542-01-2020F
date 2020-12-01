class ProcessImportResult < String
  def initialize val
    super(val)
  end

  def error?
    false
  end
end

describe UpdateModelFieldsSupport do
  before do
    User.current = FactoryBot(:user)
  end

  describe "update_model_field_attributes" do
    let(:prod_cd) { FactoryBot(:custom_definition, module_type: 'Product', data_type: :string) }
    let(:class_cd) { FactoryBot(:custom_definition, module_type: 'Classification', data_type: :decimal) }
    let(:tariff_cd) { FactoryBot(:custom_definition, module_type: 'TariffRecord', data_type: :date) }
    let(:country) { FactoryBot(:country) }

    it "updates model field attributes and custom fields (creating new nested children) using request params hash layout" do
      params = {
        'prod_uid' => 'unique_id',
        prod_cd.model_field_uid => 'custom',
        'classifications_attributes' => {'0' => {
          'class_cntry_iso' => country.iso_code,
          class_cd.model_field_uid => '12.3',
          'tariff_records_attributes' => {'0' => {
            'hts_line_number' => '1',
            'hts_hts_1' => '1234.56.7890',
            tariff_cd.model_field_uid => '2014-12-01'
          }}
        }}
      }

      p = Product.new

      expect(p.update_model_field_attributes(params)).to be_truthy
      expect(p.unique_identifier).to eq "unique_id"
      expect(p.get_custom_value(prod_cd).value).to eq 'custom'
      expect(p.classifications.length).to eq 1
      expect(p.classifications.first.country).to eq country
      expect(p.classifications.first.get_custom_value(class_cd).value).to eq 12.3
      expect(p.classifications.first.tariff_records.length).to eq 1
      expect(p.classifications.first.tariff_records.first.hts_1).to eq "1234567890"
      expect(p.classifications.first.tariff_records.first.get_custom_value(tariff_cd).value).to eq Date.new(2014, 12, 1)

      expect(p.last_updated_by).to eq User.current
    end

    it "updates existing models adding new child model" do
      p = FactoryBot(:product, unique_identifier: "unique_id")
      cl = FactoryBot(:classification, product: p)
      FactoryBot(:tariff_record, classification: cl, line_number: 1, hts_1: "9876543210")

      params = {
        'id' => p.id,
        'classifications_attributes' => {'0' => {
          'class_cntry_iso' => country.iso_code,
          class_cd.model_field_uid => '12.3'
        }}
      }

      expect(p.update_model_field_attributes(params)).to be_truthy

      classifications = p.classifications.collect {|c| c}
      expect(classifications.length).to eq 2

      expect(classifications.first.id).to eq cl.id
      expect(classifications.first.country).to eq cl.country

      expect(classifications.second.country).to eq country
      expect(classifications.second.get_custom_value(class_cd).value).to eq 12.3

      expect(p.last_updated_by).to eq User.current
    end

    it "updates existing models adding new grand-child model" do
      p = FactoryBot(:product, unique_identifier: "unique_id")
      cl = FactoryBot(:classification, product: p)
      FactoryBot(:tariff_record, classification: cl, line_number: 1, hts_1: "9876543210")

      params = {
        'id' => p.id,
        'classifications_attributes' => {'0' => {
          'id' => cl.id,
          'tariff_records_attributes' => {'0' => {
            'hts_line_number' => 2,
            'hts_hts_1' => '1234567890',
            tariff_cd.model_field_uid => '2014-12-01'
          }}
        }}
      }

      expect(p.update_model_field_attributes(params)).to be_truthy

      classifications = p.classifications.collect {|c| c}
      expect(classifications.length).to eq 1

      expect(classifications.first.tariff_records.length).to eq 2
      expect(classifications.first.tariff_records.first.hts_1).to eq "9876543210"

      expect(classifications.first.tariff_records.second.line_number).to eq 2
      expect(classifications.first.tariff_records.second.hts_1).to eq "1234567890"
      expect(classifications.first.tariff_records.second.get_custom_value(tariff_cd).value).to eq Date.new(2014, 12, 1)

      expect(p.last_updated_by).to eq User.current
    end

    it "updates model field attributes and custom fields (creating new nested children) using 'standard' hash layout" do
      params = {
        :prod_uid => 'unique_id',
        prod_cd.model_field_uid.to_sym => 'custom',
        :classifications_attributes => [{
          :class_cntry_iso => country.iso_code,
          class_cd.model_field_uid.to_sym => '12.3',
          :tariff_records_attributes => [{
            :hts_line_number => '1',
            :hts_hts_1 => '1234.56.7890',
            tariff_cd.model_field_uid.to_sym => '2014-12-01'
          }]
        }]
      }

      p = Product.new
      expect(p.update_model_field_attributes(params)).to be_truthy
      expect(p.unique_identifier).to eq "unique_id"
      expect(p.get_custom_value(prod_cd).value).to eq 'custom'
      expect(p.classifications.length).to eq 1
      expect(p.classifications.first.country).to eq country
      expect(p.classifications.first.get_custom_value(class_cd).value).to eq 12.3
      expect(p.classifications.first.tariff_records.length).to eq 1
      expect(p.classifications.first.tariff_records.first.hts_1).to eq "1234567890"
      expect(p.classifications.first.tariff_records.first.get_custom_value(tariff_cd).value).to eq Date.new(2014, 12, 1)

      expect(p.last_updated_by).to eq User.current
    end

    it "updates model field attributes and custom fields (creating new nested children) using 'abbreviated' hash layout" do
      params = {
        :prod_uid => 'unique_id',
        prod_cd.model_field_uid.to_sym => 'custom',
        :classifications => [{
          :class_cntry_iso => country.iso_code,
          class_cd.model_field_uid.to_sym => '12.3',
          :tariff_records => [{
            :hts_line_number => '1',
            :hts_hts_1 => '1234.56.7890',
            tariff_cd.model_field_uid.to_sym => '2014-12-01'
          }]
        }]
      }

      p = Product.new
      expect(p.update_model_field_attributes(params)).to be_truthy
      expect(p.unique_identifier).to eq "unique_id"
      expect(p.get_custom_value(prod_cd).value).to eq 'custom'
      expect(p.classifications.length).to eq 1
      expect(p.classifications.first.country).to eq country
      expect(p.classifications.first.get_custom_value(class_cd).value).to eq 12.3
      expect(p.classifications.first.tariff_records.length).to eq 1
      expect(p.classifications.first.tariff_records.first.hts_1).to eq "1234567890"
      expect(p.classifications.first.tariff_records.first.get_custom_value(tariff_cd).value).to eq Date.new(2014, 12, 1)

      expect(p.last_updated_by).to eq User.current
    end

    it "does not raise an error on active record validation errors" do
      existing = FactoryBot(:product)
      p = Product.new

      # Product has a unique identifier validation
      expect(p.update_model_field_attributes(prod_uid: existing.unique_identifier)).to be_falsey
      expect(p.errors.full_messages).to include "Unique identifier has already been taken"
    end

    it "does not raise an error on model field import validation errors" do
      result = ProcessImportResult.new "fail"
      allow(result).to receive(:error?).and_return true
      expect_any_instance_of(ModelField).to receive(:process_import).and_return result

      p = Product.new
      expect(p.update_model_field_attributes(prod_uid: 'id')).to be_falsey
      expect(p.errors[:base]).to eq ["fail"]
    end

    it "includes both ActiveRecord and model field import errors in errors" do
      existing = FactoryBot(:product)
      p = Product.new

      result = ProcessImportResult.new "fail"
      allow(result).to receive(:error?).and_return true
      expect_any_instance_of(ModelField).to receive(:process_import).and_return result

      # Product has a unique identifier validation
      expect(p.update_model_field_attributes(prod_uid: existing.unique_identifier)).to be_falsey
      expect(p.errors.full_messages).to include "Unique identifier can't be blank"
      expect(p.errors.full_messages).to include "fail"
    end

    it "skips fields that user cannot edit" do
      p = FactoryBot(:product, name: 'XYZ')
      mf = ModelField.by_uid(:prod_name)
      u = FactoryBot(:user)
      attrs = { prod_name: 'ABC'}
      opts = {user: u, skip_not_editable: true}

      allow(mf).to receive(:can_edit?).with(u).and_return false

      p.update_model_field_attributes(attrs, opts)
      expect(p.errors.blank?).to be_truthy
      p.reload
      expect(p.name).to eq 'XYZ'
    end
  end

  describe "update_model_field_attributes!" do
    let(:prod_cd) { FactoryBot(:custom_definition, module_type: 'Product', data_type: :string) }
    let(:class_cd) { FactoryBot(:custom_definition, module_type: 'Classification', data_type: :decimal) }
    let(:tariff_cd) { FactoryBot(:custom_definition, module_type: 'TariffRecord', data_type: :date) }
    let(:country) { FactoryBot(:country) }

    it "updates model field attributes and custom fields (creating new nested children) using request params hash layout" do
      params = {
        'prod_uid' => 'unique_id',
        prod_cd.model_field_uid => 'custom',
        'classifications_attributes' => {'0' => {
          'class_cntry_iso' => country.iso_code,
          class_cd.model_field_uid => '12.3',
          'tariff_records_attributes' => {'0' => {
            'hts_line_number' => '1',
            'hts_hts_1' => '1234.56.7890',
            tariff_cd.model_field_uid => '2014-12-01'
          }}
        }}
      }

      p = Product.new
      expect(p.update_model_field_attributes!(params)).to be_truthy
      expect(p.unique_identifier).to eq "unique_id"
      expect(p.get_custom_value(prod_cd).value).to eq 'custom'
      expect(p.classifications.length).to eq 1
      expect(p.classifications.first.country).to eq country
      expect(p.classifications.first.get_custom_value(class_cd).value).to eq 12.3
      expect(p.classifications.first.tariff_records.length).to eq 1
      expect(p.classifications.first.tariff_records.first.hts_1).to eq "1234567890"
      expect(p.classifications.first.tariff_records.first.get_custom_value(tariff_cd).value).to eq Date.new(2014, 12, 1)

      expect(p.last_updated_by).to eq User.current
    end

    it "updates model field attributes and custom fields (creating new nested children) using 'standard' hash layout" do
      params = {
        :prod_uid => 'unique_id',
        prod_cd.model_field_uid.to_sym => 'custom',
        :classifications_attributes => [{
          :class_cntry_id => country.id.to_s,
          class_cd.model_field_uid.to_sym => '12.3',
          :tariff_records_attributes => [{
            :hts_line_number => '1',
            :hts_hts_1 => '1234.56.7890',
            tariff_cd.model_field_uid.to_sym => '2014-12-01'
          }]
        }]
      }

      p = Product.new
      expect(p.update_model_field_attributes!(params)).to be_truthy
      expect(p.unique_identifier).to eq "unique_id"
      expect(p.get_custom_value(prod_cd).value).to eq 'custom'
      expect(p.classifications.length).to eq 1
      expect(p.classifications.first.country).to eq country
      expect(p.classifications.first.get_custom_value(class_cd).value).to eq 12.3
      expect(p.classifications.first.tariff_records.length).to eq 1
      expect(p.classifications.first.tariff_records.first.hts_1).to eq "1234567890"
      expect(p.classifications.first.tariff_records.first.get_custom_value(tariff_cd).value).to eq Date.new(2014, 12, 1)

      expect(p.last_updated_by).to eq User.current
    end

    it "updates model field attributes and custom fields (creating new nested children) using 'abbreviated' hash layout" do
      params = {
        :prod_uid => 'unique_id',
        prod_cd.model_field_uid.to_sym => 'custom',
        :classifications => [{
          :class_cntry_id => country.id.to_s,
          class_cd.model_field_uid.to_sym => '12.3',
          :tariff_records => [{
            :hts_line_number => '1',
            :hts_hts_1 => '1234.56.7890',
            tariff_cd.model_field_uid.to_sym => '2014-12-01'
          }]
        }]
      }

      p = Product.new
      expect(p.update_model_field_attributes!(params)).to be_truthy
      expect(p.unique_identifier).to eq "unique_id"
      expect(p.get_custom_value(prod_cd).value).to eq 'custom'
      expect(p.classifications.length).to eq 1
      expect(p.classifications.first.country).to eq country
      expect(p.classifications.first.get_custom_value(class_cd).value).to eq 12.3
      expect(p.classifications.first.tariff_records.length).to eq 1
      expect(p.classifications.first.tariff_records.first.hts_1).to eq "1234567890"
      expect(p.classifications.first.tariff_records.first.get_custom_value(tariff_cd).value).to eq Date.new(2014, 12, 1)

      expect(p.last_updated_by).to eq User.current
    end

    it "does raises an error on active record validation errors" do
      existing = FactoryBot(:product)
      p = Product.new

      # Product has a unique identifier validation
      begin
        p.update_model_field_attributes! prod_uid: existing.unique_identifier
        raise
      rescue ActiveRecord::RecordInvalid => e
        expect(e.record.errors.full_messages).to include "Unique identifier has already been taken"
      end
    end

    it "raises an error on model field import validation errors" do
      result = ProcessImportResult.new "fail"
      allow(result).to receive(:error?).and_return true
      expect_any_instance_of(ModelField).to receive(:process_import).and_return result

      p = Product.new
      begin
        p.update_model_field_attributes! prod_uid: 'id'
        raise
      rescue ActiveRecord::RecordInvalid => e
        expect(e.record.errors.full_messages).to include "fail"
      end
    end

    it "includes both ActiveRecord and model field import errors in errors" do
      existing = FactoryBot(:product)
      p = Product.new

      result = ProcessImportResult.new "fail"
      allow(result).to receive(:error?).and_return true
      expect_any_instance_of(ModelField).to receive(:process_import).and_return result

      begin
        p.update_model_field_attributes! prod_uid: existing.unique_identifier
        raise
      rescue ActiveRecord::RecordInvalid => e
        expect(e.record.errors.full_messages).to include "Unique identifier can't be blank"
        expect(e.record.errors.full_messages).to include "fail"
      end
    end

    it "skips blank fields when instructed to with params-style hash" do
      p = FactoryBot(:product, unique_identifier: "unique_id", unit_of_measure: "UOM")
      p.update_custom_value! prod_cd, 'custom'
      cl = FactoryBot(:classification, product: p)
      t = FactoryBot(:tariff_record, classification: cl, line_number: 1, hts_1: "9876543210")

      params = {
        'id' => p.id,
        'prod_uom' => "",
        'prod_name' => "NAME",
        prod_cd.model_field_uid.to_s => "",
        'classifications_attributes' => {'0' => {
          'id' => cl.id,
          'tariff_records_attributes' => {'0' => {
            'id' => t.id,
            'hts_hts_1' => '',
            tariff_cd.model_field_uid => '2014-12-01'
          }}
        }}
      }

      expect(p.update_model_field_attributes(params, exclude_blank_values: true)).to be_truthy
      expect(p.unit_of_measure).to eq "UOM"
      expect(p.name).to eq "NAME"
      expect(p.get_custom_value(prod_cd).value).to eq 'custom'
      tr = p.classifications.first.tariff_records.first
      expect(tr.hts_1).to eq "9876543210"
      expect(tr.get_custom_value(tariff_cd).value).to eq Date.new(2014, 12, 1)

    end

    it "skips blank fields when instructed to with standard hash" do
      p = FactoryBot(:product, unique_identifier: "unique_id", unit_of_measure: "UOM")
      p.update_custom_value! prod_cd, 'custom'
      cl = FactoryBot(:classification, product: p)
      t = FactoryBot(:tariff_record, classification: cl, line_number: 1, hts_1: "9876543210")

      params = {
        'id' => p.id,
        'prod_uom' => "",
        'prod_name' => "NAME",
        prod_cd.model_field_uid.to_s => "",
        'classifications_attributes' => [{
          'id' => cl.id,
          'tariff_records_attributes' => [{
            'id' => t.id,
            'hts_hts_1' => '',
            tariff_cd.model_field_uid.to_s => '2014-12-01'
          }]
        }]
      }

      expect(p.update_model_field_attributes!(params, exclude_blank_values: true)).to be_truthy
      expect(p.unit_of_measure).to eq "UOM"
      expect(p.name).to eq "NAME"
      expect(p.get_custom_value(prod_cd).value).to eq 'custom'
      tr = p.classifications.first.tariff_records.first

      expect(tr.hts_1).to eq "9876543210"
      expect(tr.get_custom_value(tariff_cd).value).to eq Date.new(2014, 12, 1)
    end

    t "skips blank fields when instructed to with abbreviated hash" do
      p = FactoryBot(:product, unique_identifier: "unique_id", unit_of_measure: "UOM")
      p.update_custom_value! prod_cd, 'custom'
      cl = FactoryBot(:classification, product: p)
      t = FactoryBot(:tariff_record, classification: cl, line_number: 1, hts_1: "9876543210")

      params = {
        'id' => p.id,
        'prod_uom' => "",
        'prod_name' => "NAME",
        prod_cd.model_field_uid.to_s => "",
        'classifications' => [{
          'id' => cl.id,
          'tariff_records' => [{
            'id' => t.id,
            'hts_hts_1' => '',
            tariff_cd.model_field_uid.to_s => '2014-12-01'
          }]
        }]
      }

      expect(p.update_model_field_attributes!(params, exclude_blank_values: true)).to be_truthy
      expect(p.unit_of_measure).to eq "UOM"
      expect(p.name).to eq "NAME"
      expect(p.get_custom_value(prod_cd).value).to eq 'custom'
      tr = p.classifications.first.tariff_records.first

      expect(tr.hts_1).to eq "9876543210"
      expect(tr.get_custom_value(tariff_cd).value).to eq Date.new(2014, 12, 1)
    end

    it "skips custom fields if instructed" do
      p = FactoryBot(:product, unique_identifier: "unique_id", unit_of_measure: "UOM")
      p.update_custom_value! prod_cd, 'custom'
      cl = FactoryBot(:classification, product: p)
      t = FactoryBot(:tariff_record, classification: cl, line_number: 1, hts_1: "9876543210")

      params = {
        'id' => p.id,
        prod_cd.model_field_uid.to_s => "another value",
        'classifications_attributes' => [{
          'id' => cl.id,
          'tariff_records_attributes' => [{
            'id' => t.id,
            tariff_cd.model_field_uid.to_s => '2014-12-01'
          }]
        }]
      }

      expect(p.update_model_field_attributes!(params, exclude_custom_fields: true)).to be_truthy
      expect(p.get_custom_value(prod_cd).value).to eq 'custom'
      tr = p.classifications.first.tariff_records.first

      expect(tr.get_custom_value(tariff_cd).value).to be_nil
    end
  end

  describe "assign_model_field_attributes" do
    let(:prod_cd) { FactoryBot(:custom_definition, module_type: 'Product', data_type: :string) }
    let(:class_cd) { FactoryBot(:custom_definition, module_type: 'Classification', data_type: :decimal) }
    let(:tariff_cd) { FactoryBot(:custom_definition, module_type: 'TariffRecord', data_type: :date) }
    let(:country) { FactoryBot(:country) }

    it "converts ActionController::Parameters to a hash" do
      params = ActionController::Parameters.new({
                                                  'prod_uid' => 'unique_id',
                                                  prod_cd.model_field_uid => 'custom',
                                                  'classifications_attributes' => {'0' => {
                                                    'class_cntry_iso' => country.iso_code,
                                                    class_cd.model_field_uid => '12.3',
                                                    'tariff_records_attributes' => {'0' => {
                                                      'hts_line_number' => '1',
                                                      'hts_hts_1' => '1234.56.7890',
                                                      tariff_cd.model_field_uid => '2014-12-01'
                                                    }}
                                                  }}
                                                })

      permitted_params = params.permit!
      hash = params.to_hash
      hash_indiferrent_access = hash.with_indifferent_access

      expect(params).to receive(:deep_dup).and_return(params)
      expect(params).to receive(:permit!).and_return(permitted_params)
      expect(permitted_params).to receive(:to_hash).and_return(hash)
      expect(hash).to receive(:with_indifferent_access).and_return(hash_indiferrent_access)

      p = Product.new
      p.assign_model_field_attributes params

      expect(p.unique_identifier).to eq "unique_id"
      expect(p.get_custom_value(prod_cd).value).to eq 'custom'
      expect(p.classifications.length).to eq 1
      expect(p.classifications.first.country).to eq country
      expect(p.classifications.first.get_custom_value(class_cd).value).to eq 12.3
      expect(p.classifications.first.tariff_records.length).to eq 1
      expect(p.classifications.first.tariff_records.first.hts_1).to eq "1234567890"
      expect(p.classifications.first.tariff_records.first.get_custom_value(tariff_cd).value).to eq Date.new(2014, 12, 1)

      expect(p.last_updated_by).to eq User.current
    end

    it "assigns values to an object without saving the object" do
      params = {
        'prod_uid' => 'unique_id',
        prod_cd.model_field_uid => 'custom',
        'classifications_attributes' => {'0' => {
          'class_cntry_iso' => country.iso_code,
          class_cd.model_field_uid => '12.3',
          'tariff_records_attributes' => {'0' => {
            'hts_line_number' => '1',
            'hts_hts_1' => '1234.56.7890',
            tariff_cd.model_field_uid => '2014-12-01'
          }}
        }}
      }

      p = Product.new
      expect(p.assign_model_field_attributes(params)).to be_truthy
      expect(p.unique_identifier).to eq "unique_id"
      expect(p.get_custom_value(prod_cd).value).to eq 'custom'
      expect(p.classifications.length).to eq 1
      expect(p.classifications.first.country).to eq country
      expect(p.classifications.first.get_custom_value(class_cd).value).to eq 12.3
      expect(p.classifications.first.tariff_records.length).to eq 1
      expect(p.classifications.first.tariff_records.first.hts_1).to eq "1234567890"
      expect(p.classifications.first.tariff_records.first.get_custom_value(tariff_cd).value).to eq Date.new(2014, 12, 1)

      expect(p.last_updated_by).to eq User.current
    end

    it "runs validations on assigned object" do
      FactoryBot(:product, unique_identifier: 'unique_id')
      result = ProcessImportResult.new "fail"
      allow(result).to receive(:error?).and_return true
      allow_any_instance_of(ModelField).to receive(:process_import).and_return result

      params = {
        'prod_uid' => 'unique_id',
        prod_cd.model_field_uid => 'custom',
        'classifications_attributes' => {'0' => {
          'class_cntry_iso' => country.iso_code,
          class_cd.model_field_uid => '12.3',
          'tariff_records_attributes' => {'0' => {
            'hts_line_number' => '1',
            'hts_hts_1' => '1234.56.7890',
            tariff_cd.model_field_uid => '2014-12-01'
          }}
        }}
      }

      p = Product.new
      expect(p.assign_model_field_attributes(params)).to be_falsey
      expect(p.errors.full_messages).to include "Unique identifier can't be blank"
      expect(p.errors.full_messages).to include "fail"
    end

    it "does not run validations on assigned object if instructed not to" do
      FactoryBot(:product, unique_identifier: 'unique_id')
      result = ProcessImportResult.new "fail"
      allow(result).to receive(:error?).and_return true
      allow(ModelField.by_uid(:prod_uid)).to receive(:process_import).and_return result

      params = {
        'prod_uid' => 'unique_id',
        'prod_uom' => "uom",
        prod_cd.model_field_uid => 'custom',
        'classifications_attributes' => {'0' => {
          'class_cntry_iso' => country.iso_code,
          class_cd.model_field_uid => '12.3',
          'tariff_records_attributes' => {'0' => {
            'hts_line_number' => '1',
            'hts_hts_1' => '1234.56.7890',
            tariff_cd.model_field_uid => '2014-12-01'
          }}
        }}
      }

      p = Product.new
      expect(p.assign_model_field_attributes(params, no_validation: true)).to be_truthy
      expect(p.errors.full_messages.size).to eq 0

      # Make sure the data was still app ssigned
      expect(p.unit_of_measure).to eq "uom"
      expect(p.classifications.length).to eq 1
      expect(p.classifications.first.tariff_records.length).to eq 1
    end

    it "rejects child attribute assignments on existing values using lambdas" do
      l = ->(attrs) { !attrs.include? :class_cntry_iso}
      expect(Product).to receive(:model_field_attribute_rejections).and_return [l]

      p = FactoryBot(:product, unique_identifier: "unique_id")
      cl = FactoryBot(:classification, product: p)

      params = {
        'id' => p.id,
        'classifications_attributes' => {'0' => {
          'id' => cl.id,
          class_cd.model_field_uid => '12.3'
        }}
      }

      expect(p.update_model_field_attributes(params)).to be_truthy

      classifications = p.classifications.collect {|c| c}
      expect(classifications.length).to eq 1
      expect(classifications.first.get_custom_value(class_cd).value).to be_nil
    end

    it "rejects child attribute assignments on new values using lambdas" do
      l = ->(attrs) { !attrs.include? :class_cntry_iso}
      expect(Product).to receive(:model_field_attribute_rejections).and_return [l]

      p = FactoryBot(:product, unique_identifier: "unique_id")
      params = {
        'id' => p.id,
        'classifications_attributes' => {'0' => {
          'class_cntry_id' => country.id,
          class_cd.model_field_uid => '12.3'
        }}
      }
      expect(p.update_model_field_attributes(params)).to be_truthy
      expect(p.classifications.length).to eq 0
    end

    it "rejects child attribute assignments on existing values using methods", :without_partial_double_verification do
      expect(Product).to receive(:model_field_attribute_rejections).and_return [:reject_me]
      expect(Product).to receive(:reject_me) {|attrs| !attrs.include? :class_cntry_iso }

      p = FactoryBot(:product, unique_identifier: "unique_id")
      cl = FactoryBot(:classification, product: p)

      params = {
        'id' => p.id,
        'classifications_attributes' => {'0' => {
          'id' => cl.id,
          class_cd.model_field_uid => '12.3'
        }}
      }

      expect(p.update_model_field_attributes(params)).to be_truthy

      classifications = p.classifications.collect {|c| c}
      expect(classifications.length).to eq 1
      expect(classifications.first.get_custom_value(class_cd).value).to be_nil
    end

    it "rejects child attribute assignments on new values using methods", :without_partial_double_verification do
      expect(Product).to receive(:model_field_attribute_rejections).and_return [:reject_me]
      expect(Product).to receive(:reject_me) {|attrs| !attrs.include? :class_cntry_iso }

      p = FactoryBot(:product, unique_identifier: "unique_id")
      params = {
        'id' => p.id,
        'classifications_attributes' => {'0' => {
          'class_cntry_id' => country.id,
          class_cd.model_field_uid => '12.3'
        }}
      }
      expect(p.update_model_field_attributes(params)).to be_truthy
      expect(p.classifications.length).to eq 0
    end

    it "does not attempt to call reject on objects marked for destruction" do
      expect(Product).not_to receive(:reject_child_model_field_assignment?)

      p = FactoryBot(:product, unique_identifier: "unique_id")
      cl = FactoryBot(:classification, product: p)

      params = {
        'classifications_attributes' => {'0' => {
          'id' => cl.id,
          '_destroy' => true
        }}
      }

      expect(p.update_model_field_attributes(params)).to be_truthy
      expect(p.classifications.length).to eq 0
    end
  end
end
