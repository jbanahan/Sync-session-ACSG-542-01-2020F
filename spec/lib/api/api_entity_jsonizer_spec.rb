require 'spec_helper'

describe OpenChain::Api::ApiEntityJsonizer do

  describe '#entity_to_json' do 
    before :each do
      @country_1 = Factory(:country)
      @country_2 = Factory(:country)

      @product = Factory(:product)
      @classification = Factory(:classification, country: @country_1, product: @product)
      @tariff_record = Factory(:tariff_record, classification: @classification, hts_1: '1234567890')

      @classification_2 = Factory(:classification, country: @country_2, product: @product)
      @tariff_record_2 = Factory(:tariff_record, classification: @classification_2, hts_1: '1234567890')    

      @user = Factory(:master_user)
    end

    it 'renders jsonized output for model fields requested' do
      # Just select a standard model field from each level for this test.
      json = OpenChain::Api::ApiEntityJsonizer.new.entity_to_json @user, @product, ['prod_uid', 'class_cntry_iso', 'hts_hts_1']

      hash = {
        'product' => {
          'id' => @product.id,
          'prod_uid'=> @product.unique_identifier,
          'classifications' => [
            {
              "id" => @classification.id,
              "class_cntry_iso" => @country_1.iso_code, 
              "tariff_records" => [
                {'id' => @tariff_record.id, 'hts_hts_1' => @tariff_record.hts_1.hts_format}
              ]
            },
            {
              "id" => @classification_2.id,
              "class_cntry_iso" => @country_2.iso_code, 
              "tariff_records" => [
                {'id' => @tariff_record_2.id, 'hts_hts_1' => @tariff_record_2.hts_1.hts_format}
              ]
            }
          ]
        }
      }
      expect(ActiveSupport::JSON.decode(json)).to eq hash
    end

    it 'skips child and grand-child levels that did not have model fields requested for them' do
      json = OpenChain::Api::ApiEntityJsonizer.new.entity_to_json @user, @product, ['prod_uid']
      hash = {
        'product' => {
          'id' => @product.id,
          'prod_uid'=> @product.unique_identifier
        }
      }
      expect(ActiveSupport::JSON.decode(json)).to eq hash
    end

    it 'skips grand-child levels that did not have model fields requested for them' do
      json = OpenChain::Api::ApiEntityJsonizer.new.entity_to_json @user, @product, ['prod_uid', 'class_cntry_iso']
      hash = {
        'product' => {
          'id' => @product.id,
          'prod_uid'=> @product.unique_identifier,
          'classifications' => [
            {
              "id" => @classification.id,
              "class_cntry_iso" => @country_1.iso_code, 
            },
            {
              "id" => @classification_2.id,
              "class_cntry_iso" => @country_2.iso_code, 
            }
          ]
        }
      }
      expect(ActiveSupport::JSON.decode(json)).to eq hash
    end

    it 'does not skip intermediary levels with no model fields if child levels have fields selected' do
      json = OpenChain::Api::ApiEntityJsonizer.new.entity_to_json @user, @product, ['prod_uid', 'hts_hts_1']
      hash = {
        'product' => {
          'id' => @product.id,
          'prod_uid'=> @product.unique_identifier,
          'classifications' => [
            {
              "id" => @classification.id,
              "tariff_records" => [
                {'id' => @tariff_record.id, 'hts_hts_1' => @tariff_record.hts_1.hts_format}
              ]
            },
            {
              "id" => @classification_2.id,
              "tariff_records" => [
                {'id' => @tariff_record_2.id, 'hts_hts_1' => @tariff_record_2.hts_1.hts_format}
              ]
            }
          ]
        }
      }
      expect(ActiveSupport::JSON.decode(json)).to eq hash
    end

    it 'sends nil/null for values not present in the entity at each level' do
      # There's no real nullable values in a product at the classification / tariff level
      # so we'll use an entry for this test
      line = Factory(:commercial_invoice_line)
      entry = line.entry
      json = OpenChain::Api::ApiEntityJsonizer.new.entity_to_json @user, entry, ['ent_div_num', 'ci_total_quantity_uom', 'cil_po_number']
      hash = {
        'entry' => {
          'id' => entry.id,
          'ent_div_num'=> nil,
          'commercial_invoices' => [
            {
              'id' => line.commercial_invoice.id,
              'ci_total_quantity_uom' => nil,
              'commercial_invoice_lines' => [
                {'id'=>line.id, 'cil_po_number' => nil}
              ]
            }
          ]
        }
      }
      expect(ActiveSupport::JSON.decode(json)).to eq hash
    end

    it "validates user access to model fields" do
      ModelField.any_instance.stub(:can_view?).with(@user).and_return false
      json = OpenChain::Api::ApiEntityJsonizer.new.entity_to_json @user, @product, ['prod_uid', 'class_cntry_iso', 'hts_hts_1']
      expect(ActiveSupport::JSON.decode(json)).to eq({'product'=>{'id'=>@product.id}})
    end

    it "skips invalid model field names" do
      json = OpenChain::Api::ApiEntityJsonizer.new.entity_to_json @user, @product, ['prod_blah', 'class_blah', 'hts_blah']
      expect(ActiveSupport::JSON.decode(json)).to eq({'product'=>{'id'=>@product.id}})
    end

    it "raises an error if the entity doesn't have a CoreModule" do
      expect{OpenChain::Api::ApiEntityJsonizer.new.entity_to_json @user, User.new, ['prod_blah', 'class_blah', 'hts_blah']}.to raise_error "CoreModule could not be found for class User."
    end

    context "with custom fields" do
      before :each do
        @p_def = Factory(:custom_definition)
        @c_def = Factory(:custom_definition, module_type: "Classification", data_type: 'date')
        @t_def = Factory(:custom_definition, module_type: "TariffRecord", data_type: 'decimal')

        @product.update_custom_value! @p_def, "Value1"
        @classification.update_custom_value! @c_def, Date.new(2013, 12, 20)
        @tariff_record.update_custom_value! @t_def, BigDecimal.new("10.99")
      end

      it "returns custom definition fields" do
        json = OpenChain::Api::ApiEntityJsonizer.new.entity_to_json @user, @product, ["*cf_#{@p_def.id}", "*cf_#{@c_def.id}", "*cf_#{@t_def.id}"]
        hash = {
          'product' => {
            'id' => @product.id,
            "*cf_#{@p_def.id}"=> "Value1",
            'classifications' => [
              {
                "id" => @classification.id,
                "*cf_#{@c_def.id}" => Date.new(2013, 12, 20).to_s, 
                "tariff_records" => [
                  {"id" => @tariff_record.id, "*cf_#{@t_def.id}" => BigDecimal.new("10.99").to_s}
                ]
              },
              {
                "id" => @classification_2.id,
                "*cf_#{@c_def.id}" => nil, 
                "tariff_records" => [
                  {"id" => @tariff_record_2.id, "*cf_#{@t_def.id}" => nil}
                ]
              }
            ]
          }
        }
        expect(ActiveSupport::JSON.decode(json)).to eq hash
      end
    end
  end

  describe 'model_field_list_to_json' do
    before :each do
      @user = Factory(:master_user)
    end

    it 'should list all model fields for Product' do
      json = OpenChain::Api::ApiEntityJsonizer.new.model_field_list_to_json @user, CoreModule::PRODUCT

      model_fields = ActiveSupport::JSON.decode(json)
      cm_fields = CoreModule::PRODUCT.model_fields(@user)

      expect(model_fields['product'].size).to eq cm_fields.size
      expect(model_fields['classification'].size).to eq CoreModule::CLASSIFICATION.model_fields(@user).size
      expect(model_fields['tariff_record'].size).to eq CoreModule::TARIFF.model_fields(@user).size

      # We can pretty much just check one of the model fields for the correct values now that we've
      # shown we're listing them all.
      mf = cm_fields[cm_fields.keys[0]]
      expect(model_fields['product'][0]).to eq ({
        'uid' => mf.uid.to_s, 
        'label' => mf.label(false),
        'data_type' => mf.data_type.to_s
      })
    end

    it "should not show model fields the user does not have access to" do
      ModelField.any_instance.stub(:can_view?).with(@user).and_return false
      json = OpenChain::Api::ApiEntityJsonizer.new.model_field_list_to_json @user, CoreModule::PRODUCT
      model_fields = ActiveSupport::JSON.decode(json)

      expect(model_fields['product']).to be_nil
      expect(model_fields['classification']).to be_nil
      expect(model_fields['tariff_record']).to be_nil
    end
  end

  describe "export_field" do
    it "outputs string data" do
      mf = ModelField.find_by_uid :prod_uid
      u = User.new
      p = Product.new unique_identifier: "ABC"

      expect(described_class.new.export_field u, p, mf).to eq "ABC"
    end

    it "outputs nil for nil values by default" do
      mf = ModelField.find_by_uid :prod_uid
      u = User.new
      p = Product.new
      expect(described_class.new.export_field u, p, mf).to be_nil
    end

    it "outputs blank for nil if specified" do
      mf = ModelField.find_by_uid :prod_uid
      u = User.new
      p = Product.new
      expect(described_class.new(blank_if_nil:true).export_field u, p, mf).to eq ""
    end

    it "outputs integer values as integers" do
      # make sure that regardless of the value returned by the process_export
      # that an actual integer is returned
      mf = double
      u = User.new
      p = Product.new
      mf.should_receive(:process_export).with(p, u).and_return "1"
      mf.should_receive(:data_type).and_return :integer
      expect(described_class.new.export_field u, p, mf).to eq 1
    end

    it "outputs decimal values as BigDecimals by default" do
      # make sure that regardless of the value returned by the process_export
      # that an actual BigDecimal is returned
      mf = double
      u = User.new
      p = Product.new
      mf.should_receive(:process_export).with(p, u).and_return "123.12"
      mf.should_receive(:data_type).and_return :decimal
      expect(described_class.new.export_field u, p, mf).to eq BigDecimal("123.12")
    end

    it "outputs numeric values as BigDecimals by default" do
      # make sure that regardless of the value returned by the process_export
      # that an actual BigDecimal is returned
      mf = double
      u = User.new
      p = Product.new
      mf.should_receive(:process_export).with(p, u).and_return "123.12"
      mf.should_receive(:data_type).and_return :numeric
      expect(described_class.new.export_field u, p, mf).to eq BigDecimal("123.12")
    end

    it "outputs numeric values as floats if specified" do
      # make sure that regardless of the value returned by the process_export
      # that an actual float is returned
      mf = double
      u = User.new
      p = Product.new
      mf.should_receive(:process_export).with(p, u).and_return "123.12"
      mf.should_receive(:data_type).and_return :numeric
      expect(described_class.new(force_big_decimal_numeric: true).export_field u, p, mf).to eq BigDecimal("123.12").to_f
    end

    it "converts datetimes to user's timezone" do
      t = Time.zone.now.in_time_zone("UTC")
      u = User.new time_zone: "Hawaii"
      p = Product.new
      mf = double
      mf.should_receive(:process_export).with(p, u).and_return t
      mf.should_receive(:data_type).and_return :datetime
      time = described_class.new.export_field u, p, mf
      expect(time).to eq t.in_time_zone("Hawaii")
    end
  end
end 