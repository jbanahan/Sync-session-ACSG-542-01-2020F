require 'spec_helper'

describe UpdateModelFieldsSupport do
  before :each do
    User.current = Factory(:user)
  end

  describe "update_model_field_attributes" do
    before :each do 
      @prod_cd = Factory(:custom_definition, :module_type=>'Product',:data_type=>:string)
      @class_cd = Factory(:custom_definition, :module_type=>'Classification',:data_type=>:decimal)
      @tariff_cd = Factory(:custom_definition, :module_type=>'TariffRecord',:data_type=>:date)
      @country = Factory(:country)
    end

    it "updates model field attributes and custom fields (creating new nested children) using request params hash layout" do
      params = {
        'prod_uid' => 'unique_id',
        @prod_cd.model_field_uid => 'custom',
        'classifications_attributes' => {'0' => {
          'class_cntry_iso' => @country.iso_code,
          @class_cd.model_field_uid => '12.3',
          'tariff_records_attributes' => {'0' => {
            'hts_line_number' => '1',
            'hts_hts_1' => '1234.56.7890',
            @tariff_cd.model_field_uid => '2014-12-01'
            }}
        }}
      }

      p = Product.new

      expect(p.update_model_field_attributes params).to be_true
      expect(p.unique_identifier).to eq "unique_id"
      expect(p.get_custom_value(@prod_cd).value).to eq 'custom'
      expect(p.classifications.length).to eq 1
      expect(p.classifications.first.country).to eq @country
      expect(p.classifications.first.get_custom_value(@class_cd).value).to eq 12.3
      expect(p.classifications.first.tariff_records.length).to eq 1
      expect(p.classifications.first.tariff_records.first.hts_1).to eq "1234567890"
      expect(p.classifications.first.tariff_records.first.get_custom_value(@tariff_cd).value).to eq Date.new(2014, 12, 1)

      expect(p.last_updated_by).to eq User.current
    end

    it "updates existing models adding new child model" do
      p = Factory(:product, unique_identifier: "unique_id")
      cl = Factory(:classification, product: p)
      t = Factory(:tariff_record, classification: cl, line_number: 1, hts_1: "9876543210")

      params = {
        'id' => p.id,
        'classifications_attributes' => {'0' => {
          'class_cntry_iso' => @country.iso_code,
          @class_cd.model_field_uid => '12.3'
          }}
      }

      expect(p.update_model_field_attributes params).to be_true

      classifications = p.classifications.collect {|c| c}
      expect(classifications.length).to eq 2

      expect(classifications.first.id).to eq cl.id
      expect(classifications.first.country).to eq cl.country

      expect(classifications.second.country).to eq @country
      expect(classifications.second.get_custom_value(@class_cd).value).to eq 12.3

      expect(p.last_updated_by).to eq User.current
    end

    it "updates existing models adding new grand-child model" do
      p = Factory(:product, unique_identifier: "unique_id")
      cl = Factory(:classification, product: p)
      t = Factory(:tariff_record, classification: cl, line_number: 1, hts_1: "9876543210")

      params = {
        'id' => p.id,
        'classifications_attributes' => {'0' => {
          'id' => cl.id,
          'tariff_records_attributes' => {'0' => {
              'hts_line_number' => 2,
              'hts_hts_1' => '1234567890',
              @tariff_cd.model_field_uid => '2014-12-01'
            }}
          }}
      }

      expect(p.update_model_field_attributes params).to be_true
      
      classifications = p.classifications.collect {|c| c}
      expect(classifications.length).to eq 1

      expect(classifications.first.tariff_records.length).to eq 2
      expect(classifications.first.tariff_records.first.hts_1).to eq "9876543210"

      expect(classifications.first.tariff_records.second.line_number).to eq 2
      expect(classifications.first.tariff_records.second.hts_1).to eq "1234567890"
      expect(classifications.first.tariff_records.second.get_custom_value(@tariff_cd).value).to eq Date.new(2014, 12, 1)

      expect(p.last_updated_by).to eq User.current
    end

    it "updates model field attributes and custom fields (creating new nested children) using 'standard' hash layout" do
      params = {
        :prod_uid => 'unique_id',
        @prod_cd.model_field_uid.to_sym => 'custom',
        :classifications_attributes => [{
          :class_cntry_iso => @country.iso_code,
          @class_cd.model_field_uid.to_sym => '12.3',
          :tariff_records_attributes => [{
            :hts_line_number => '1',
            :hts_hts_1 => '1234.56.7890',
            @tariff_cd.model_field_uid.to_sym => '2014-12-01'
          }]
        }]
      }

      p = Product.new
      expect(p.update_model_field_attributes params).to be_true
      expect(p.unique_identifier).to eq "unique_id"
      expect(p.get_custom_value(@prod_cd).value).to eq 'custom'
      expect(p.classifications.length).to eq 1
      expect(p.classifications.first.country).to eq @country
      expect(p.classifications.first.get_custom_value(@class_cd).value).to eq 12.3
      expect(p.classifications.first.tariff_records.length).to eq 1
      expect(p.classifications.first.tariff_records.first.hts_1).to eq "1234567890"
      expect(p.classifications.first.tariff_records.first.get_custom_value(@tariff_cd).value).to eq Date.new(2014, 12, 1)

      expect(p.last_updated_by).to eq User.current
    end

    it "updates model field attributes and custom fields (creating new nested children) using 'abbreviated' hash layout" do
      params = {
        :prod_uid => 'unique_id',
        @prod_cd.model_field_uid.to_sym => 'custom',
        :classifications => [{
          :class_cntry_iso => @country.iso_code,
          @class_cd.model_field_uid.to_sym => '12.3',
          :tariff_records => [{
            :hts_line_number => '1',
            :hts_hts_1 => '1234.56.7890',
            @tariff_cd.model_field_uid.to_sym => '2014-12-01'
          }]
        }]
      }

      p = Product.new
      expect(p.update_model_field_attributes params).to be_true
      expect(p.unique_identifier).to eq "unique_id"
      expect(p.get_custom_value(@prod_cd).value).to eq 'custom'
      expect(p.classifications.length).to eq 1
      expect(p.classifications.first.country).to eq @country
      expect(p.classifications.first.get_custom_value(@class_cd).value).to eq 12.3
      expect(p.classifications.first.tariff_records.length).to eq 1
      expect(p.classifications.first.tariff_records.first.hts_1).to eq "1234567890"
      expect(p.classifications.first.tariff_records.first.get_custom_value(@tariff_cd).value).to eq Date.new(2014, 12, 1)

      expect(p.last_updated_by).to eq User.current
    end

    it "does not raise an error on active record validation errors" do
      existing = Factory(:product)
      p = Product.new

      # Product has a unique identifier validation
      expect(p.update_model_field_attributes prod_uid: existing.unique_identifier).to be_false
      expect(p.errors.full_messages).to include "Unique identifier has already been taken"
    end

    it "does not raise an error on model field import validation errors" do
      result = "fail"
      result.stub(:error?).and_return true
      ModelField.any_instance.should_receive(:process_import).and_return result

      p = Product.new
      expect(p.update_model_field_attributes prod_uid: 'id').to be_false
      expect(p.errors[:base]).to eq ["fail"]
    end

    it "includes both ActiveRecord and model field import errors in errors" do
      existing = Factory(:product)
      p = Product.new

      result = "fail"
      result.stub(:error?).and_return true
      ModelField.any_instance.should_receive(:process_import).and_return result

      # Product has a unique identifier validation
      expect(p.update_model_field_attributes prod_uid: existing.unique_identifier).to be_false
      expect(p.errors.full_messages).to include "Unique identifier can't be blank"
      expect(p.errors.full_messages).to include "fail"
    end
  end

  describe "update_model_field_attributes!" do
    before :each do 
      @prod_cd = Factory(:custom_definition, :module_type=>'Product',:data_type=>:string)
      @class_cd = Factory(:custom_definition, :module_type=>'Classification',:data_type=>:decimal)
      @tariff_cd = Factory(:custom_definition, :module_type=>'TariffRecord',:data_type=>:date)
      @country = Factory(:country)
    end

    it "updates model field attributes and custom fields (creating new nested children) using request params hash layout" do
      params = {
        'prod_uid' => 'unique_id',
        @prod_cd.model_field_uid => 'custom',
        'classifications_attributes' => {'0' => {
          'class_cntry_iso' => @country.iso_code,
          @class_cd.model_field_uid => '12.3',
          'tariff_records_attributes' => {'0' => {
            'hts_line_number' => '1',
            'hts_hts_1' => '1234.56.7890',
            @tariff_cd.model_field_uid => '2014-12-01'
            }}
        }}
      }

      p = Product.new
      expect(p.update_model_field_attributes! params).to be_true
      expect(p.unique_identifier).to eq "unique_id"
      expect(p.get_custom_value(@prod_cd).value).to eq 'custom'
      expect(p.classifications.length).to eq 1
      expect(p.classifications.first.country).to eq @country
      expect(p.classifications.first.get_custom_value(@class_cd).value).to eq 12.3
      expect(p.classifications.first.tariff_records.length).to eq 1
      expect(p.classifications.first.tariff_records.first.hts_1).to eq "1234567890"
      expect(p.classifications.first.tariff_records.first.get_custom_value(@tariff_cd).value).to eq Date.new(2014, 12, 1)

      expect(p.last_updated_by).to eq User.current
    end

    it "updates model field attributes and custom fields (creating new nested children) using 'standard' hash layout" do
      params = {
        :prod_uid => 'unique_id',
        @prod_cd.model_field_uid.to_sym => 'custom',
        :classifications_attributes => [{
          :class_cntry_id => @country.id.to_s,
          @class_cd.model_field_uid.to_sym => '12.3',
          :tariff_records_attributes => [{
            :hts_line_number => '1',
            :hts_hts_1 => '1234.56.7890',
            @tariff_cd.model_field_uid.to_sym => '2014-12-01'
          }]
        }]
      }

      p = Product.new
      expect(p.update_model_field_attributes! params).to be_true
      expect(p.unique_identifier).to eq "unique_id"
      expect(p.get_custom_value(@prod_cd).value).to eq 'custom'
      expect(p.classifications.length).to eq 1
      expect(p.classifications.first.country).to eq @country
      expect(p.classifications.first.get_custom_value(@class_cd).value).to eq 12.3
      expect(p.classifications.first.tariff_records.length).to eq 1
      expect(p.classifications.first.tariff_records.first.hts_1).to eq "1234567890"
      expect(p.classifications.first.tariff_records.first.get_custom_value(@tariff_cd).value).to eq Date.new(2014, 12, 1)

      expect(p.last_updated_by).to eq User.current
    end

    it "updates model field attributes and custom fields (creating new nested children) using 'abbreviated' hash layout" do
      params = {
        :prod_uid => 'unique_id',
        @prod_cd.model_field_uid.to_sym => 'custom',
        :classifications => [{
          :class_cntry_id => @country.id.to_s,
          @class_cd.model_field_uid.to_sym => '12.3',
          :tariff_records => [{
            :hts_line_number => '1',
            :hts_hts_1 => '1234.56.7890',
            @tariff_cd.model_field_uid.to_sym => '2014-12-01'
          }]
        }]
      }

      p = Product.new
      expect(p.update_model_field_attributes! params).to be_true
      expect(p.unique_identifier).to eq "unique_id"
      expect(p.get_custom_value(@prod_cd).value).to eq 'custom'
      expect(p.classifications.length).to eq 1
      expect(p.classifications.first.country).to eq @country
      expect(p.classifications.first.get_custom_value(@class_cd).value).to eq 12.3
      expect(p.classifications.first.tariff_records.length).to eq 1
      expect(p.classifications.first.tariff_records.first.hts_1).to eq "1234567890"
      expect(p.classifications.first.tariff_records.first.get_custom_value(@tariff_cd).value).to eq Date.new(2014, 12, 1)

      expect(p.last_updated_by).to eq User.current
    end

    it "does raises an error on active record validation errors" do
      existing = Factory(:product)
      p = Product.new

      # Product has a unique identifier validation
      begin
        p.update_model_field_attributes! prod_uid: existing.unique_identifier
        fail
      rescue ActiveRecord::RecordInvalid => e
        expect(e.record.errors.full_messages).to include "Unique identifier has already been taken"
      end
    end

    it "raises an error on model field import validation errors" do
      result = "fail"
      result.stub(:error?).and_return true
      ModelField.any_instance.should_receive(:process_import).and_return result

      p = Product.new
      begin
        p.update_model_field_attributes! prod_uid: 'id'
        fail
      rescue ActiveRecord::RecordInvalid => e
        expect(e.record.errors.full_messages).to include "fail"
      end
    end

    it "includes both ActiveRecord and model field import errors in errors" do
      existing = Factory(:product)
      p = Product.new

      result = "fail"
      result.stub(:error?).and_return true
      ModelField.any_instance.should_receive(:process_import).and_return result

      begin
        p.update_model_field_attributes! prod_uid: existing.unique_identifier
        fail
      rescue ActiveRecord::RecordInvalid => e
        expect(e.record.errors.full_messages).to include "Unique identifier can't be blank"
        expect(e.record.errors.full_messages).to include "fail"
      end
    end

    it "skips blank fields when instructed to with params-style hash" do
      p = Factory(:product, unique_identifier: "unique_id", unit_of_measure: "UOM")
      p.update_custom_value! @prod_cd, 'custom'
      cl = Factory(:classification, product: p)
      t = Factory(:tariff_record, classification: cl, line_number: 1, hts_1: "9876543210")

      params = {
        'id' => p.id,
        'prod_uom' => "",
        'prod_name' => "NAME",
        @prod_cd.model_field_uid.to_s => "",
        'classifications_attributes' => {'0' => {
          'id' => cl.id,
          'tariff_records_attributes' => {'0' => {
              'id' => t.id,
              'hts_hts_1' => '',
              @tariff_cd.model_field_uid => '2014-12-01'
            }}
          }}
      }

      expect(p.update_model_field_attributes params, exclude_blank_values:true).to be_true
      expect(p.unit_of_measure).to eq "UOM"
      expect(p.name).to eq "NAME"
      expect(p.get_custom_value(@prod_cd).value).to eq 'custom'
      tr = p.classifications.first.tariff_records.first
      expect(tr.hts_1).to eq "9876543210"
      expect(tr.get_custom_value(@tariff_cd).value).to eq Date.new(2014, 12, 1)

    end

    it "skips blank fields when instructed to with standard hash" do
      p = Factory(:product, unique_identifier: "unique_id", unit_of_measure: "UOM")
      p.update_custom_value! @prod_cd, 'custom'
      cl = Factory(:classification, product: p)
      t = Factory(:tariff_record, classification: cl, line_number: 1, hts_1: "9876543210")

      params = {
        'id' => p.id,
        'prod_uom' => "",
        'prod_name' => "NAME",
        @prod_cd.model_field_uid.to_s => "",
        'classifications_attributes' => [{
          'id' => cl.id,
          'tariff_records_attributes' => [{
              'id' => t.id,
              'hts_hts_1' => '',
              @tariff_cd.model_field_uid.to_s => '2014-12-01'
            }]
          }]
      }

      expect(p.update_model_field_attributes! params, exclude_blank_values:true).to be_true
      expect(p.unit_of_measure).to eq "UOM"
      expect(p.name).to eq "NAME"
      expect(p.get_custom_value(@prod_cd).value).to eq 'custom'
      tr = p.classifications.first.tariff_records.first

      expect(tr.hts_1).to eq "9876543210"
      expect(tr.get_custom_value(@tariff_cd).value).to eq Date.new(2014, 12, 1)
    end

    t "skips blank fields when instructed to with abbreviated hash" do
      p = Factory(:product, unique_identifier: "unique_id", unit_of_measure: "UOM")
      p.update_custom_value! @prod_cd, 'custom'
      cl = Factory(:classification, product: p)
      t = Factory(:tariff_record, classification: cl, line_number: 1, hts_1: "9876543210")

      params = {
        'id' => p.id,
        'prod_uom' => "",
        'prod_name' => "NAME",
        @prod_cd.model_field_uid.to_s => "",
        'classifications' => [{
          'id' => cl.id,
          'tariff_records' => [{
              'id' => t.id,
              'hts_hts_1' => '',
              @tariff_cd.model_field_uid.to_s => '2014-12-01'
            }]
          }]
      }

      expect(p.update_model_field_attributes! params, exclude_blank_values:true).to be_true
      expect(p.unit_of_measure).to eq "UOM"
      expect(p.name).to eq "NAME"
      expect(p.get_custom_value(@prod_cd).value).to eq 'custom'
      tr = p.classifications.first.tariff_records.first

      expect(tr.hts_1).to eq "9876543210"
      expect(tr.get_custom_value(@tariff_cd).value).to eq Date.new(2014, 12, 1)
    end

    it "skips custom fields if instructed" do
      p = Factory(:product, unique_identifier: "unique_id", unit_of_measure: "UOM")
      p.update_custom_value! @prod_cd, 'custom'
      cl = Factory(:classification, product: p)
      t = Factory(:tariff_record, classification: cl, line_number: 1, hts_1: "9876543210")

      params = {
        'id' => p.id,
        @prod_cd.model_field_uid.to_s => "another value",
        'classifications_attributes' => [{
          'id' => cl.id,
          'tariff_records_attributes' => [{
              'id' => t.id,
              @tariff_cd.model_field_uid.to_s => '2014-12-01'
            }]
          }]
      }

      expect(p.update_model_field_attributes! params, exclude_custom_fields:true).to be_true
      expect(p.get_custom_value(@prod_cd).value).to eq 'custom'
      tr = p.classifications.first.tariff_records.first

      expect(tr.get_custom_value(@tariff_cd).value).to be_nil
    end
  end

  describe "assign_model_field_attributes" do
    before :each do 
      @prod_cd = Factory(:custom_definition, :module_type=>'Product',:data_type=>:string)
      @class_cd = Factory(:custom_definition, :module_type=>'Classification',:data_type=>:decimal)
      @tariff_cd = Factory(:custom_definition, :module_type=>'TariffRecord',:data_type=>:date)
      @country = Factory(:country)
    end

    it "assigns values to an object without saving the object" do
      params = {
        'prod_uid' => 'unique_id',
        @prod_cd.model_field_uid => 'custom',
        'classifications_attributes' => {'0' => {
          'class_cntry_iso' => @country.iso_code,
          @class_cd.model_field_uid => '12.3',
          'tariff_records_attributes' => {'0' => {
            'hts_line_number' => '1',
            'hts_hts_1' => '1234.56.7890',
            @tariff_cd.model_field_uid => '2014-12-01'
            }}
        }}
      }

      p = Product.new
      expect(p.assign_model_field_attributes params).to be_true
      expect(p.unique_identifier).to eq "unique_id"
      expect(p.get_custom_value(@prod_cd).value).to eq 'custom'
      expect(p.classifications.length).to eq 1
      expect(p.classifications.first.country).to eq @country
      expect(p.classifications.first.get_custom_value(@class_cd).value).to eq 12.3
      expect(p.classifications.first.tariff_records.length).to eq 1
      expect(p.classifications.first.tariff_records.first.hts_1).to eq "1234567890"
      expect(p.classifications.first.tariff_records.first.get_custom_value(@tariff_cd).value).to eq Date.new(2014, 12, 1)

      expect(p.last_updated_by).to eq User.current
    end

    it "runs validations on assigned object" do
      existing = Factory(:product, unique_identifier: 'unique_id')
      result = "fail"
      result.stub(:error?).and_return true
      ModelField.any_instance.stub(:process_import).and_return result

      params = {
        'prod_uid' => 'unique_id',
        @prod_cd.model_field_uid => 'custom',
        'classifications_attributes' => {'0' => {
          'class_cntry_iso' => @country.iso_code,
          @class_cd.model_field_uid => '12.3',
          'tariff_records_attributes' => {'0' => {
            'hts_line_number' => '1',
            'hts_hts_1' => '1234.56.7890',
            @tariff_cd.model_field_uid => '2014-12-01'
            }}
        }}
      }

      p = Product.new
      expect(p.assign_model_field_attributes params).to be_false
      expect(p.errors.full_messages).to include "Unique identifier can't be blank"
      expect(p.errors.full_messages).to include "fail"
    end

    it "does not run validations on assigned object if instructed not to" do
      existing = Factory(:product, unique_identifier: 'unique_id')
      result = "fail"
      result.stub(:error?).and_return true
      ModelField.find_by_uid(:prod_uid).stub(:process_import).and_return result

      params = {
        'prod_uid' => 'unique_id',
        'prod_uom' => "uom",
        @prod_cd.model_field_uid => 'custom',
        'classifications_attributes' => {'0' => {
          'class_cntry_iso' => @country.iso_code,
          @class_cd.model_field_uid => '12.3',
          'tariff_records_attributes' => {'0' => {
            'hts_line_number' => '1',
            'hts_hts_1' => '1234.56.7890',
            @tariff_cd.model_field_uid => '2014-12-01'
            }}
        }}
      }

      p = Product.new
      expect(p.assign_model_field_attributes params, no_validation: true).to be_true
      expect(p.errors.full_messages.size).to eq 0

      # Make sure the data was still app ssigned
      expect(p.unit_of_measure).to eq "uom"
      expect(p.classifications.length).to eq 1
      expect(p.classifications.first.tariff_records.length).to eq 1
    end

    it "rejects child attribute assignments on existing values using lambdas" do
      l = lambda {|attrs| !attrs.include? :class_cntry_iso}
      Product.should_receive(:model_field_attribute_rejections).and_return [l]

      p = Factory(:product, unique_identifier: "unique_id")
      cl = Factory(:classification, product: p)

      params = {
        'id' => p.id,
        'classifications_attributes' => {'0' => {
          'id' => cl.id,
          @class_cd.model_field_uid => '12.3'
          }}
      }

      expect(p.update_model_field_attributes params).to be_true
      
      classifications = p.classifications.collect {|c| c}
      expect(classifications.length).to eq 1
      expect(classifications.first.get_custom_value(@class_cd).value).to be_nil
    end

    it "rejects child attribute assignments on new values using lambdas" do
      l = lambda {|attrs| !attrs.include? :class_cntry_iso}
      Product.should_receive(:model_field_attribute_rejections).and_return [l]

      p = Factory(:product, unique_identifier: "unique_id")
      params = {
        'id' => p.id,
        'classifications_attributes' => {'0' => {
          'class_cntry_id' => @country.id,
          @class_cd.model_field_uid => '12.3'
          }}
      }
      expect(p.update_model_field_attributes params).to be_true
      expect(p.classifications.length).to eq 0
    end

    it "rejects child attribute assignments on existing values using methods" do
      Product.should_receive(:model_field_attribute_rejections).and_return [:reject_me]
      Product.should_receive(:reject_me) {|attrs| !attrs.include? :class_cntry_iso }

      p = Factory(:product, unique_identifier: "unique_id")
      cl = Factory(:classification, product: p)

      params = {
        'id' => p.id,
        'classifications_attributes' => {'0' => {
          'id' => cl.id,
          @class_cd.model_field_uid => '12.3'
          }}
      }

      expect(p.update_model_field_attributes params).to be_true
      
      classifications = p.classifications.collect {|c| c}
      expect(classifications.length).to eq 1
      expect(classifications.first.get_custom_value(@class_cd).value).to be_nil
    end

    it "rejects child attribute assignments on new values using methods" do
      Product.should_receive(:model_field_attribute_rejections).and_return [:reject_me]
      Product.should_receive(:reject_me) {|attrs| !attrs.include? :class_cntry_iso }

      p = Factory(:product, unique_identifier: "unique_id")
      params = {
        'id' => p.id,
        'classifications_attributes' => {'0' => {
          'class_cntry_id' => @country.id,
          @class_cd.model_field_uid => '12.3'
          }}
      }
      expect(p.update_model_field_attributes params).to be_true
      expect(p.classifications.length).to eq 0
    end

    it "does not attempt to call reject on objects marked for destruction" do
      Product.should_not_receive(:reject_child_model_field_assignment?)

      p = Factory(:product, unique_identifier: "unique_id")
      cl = Factory(:classification, product: p)

      params = {
        'classifications_attributes' => {'0' => {
          'id' => cl.id,
          '_destroy' => true
          }}
      }

      expect(p.update_model_field_attributes params).to be_true
      expect(p.classifications.length).to eq 0
    end
  end
end