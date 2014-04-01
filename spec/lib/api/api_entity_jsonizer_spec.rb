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
              "class_cntry_iso" => @country_1.iso_code, 
              "tariff_records" => [
                {'hts_hts_1' => @tariff_record.hts_1.hts_format}
              ]
            },
            {
              "class_cntry_iso" => @country_2.iso_code, 
              "tariff_records" => [
                {'hts_hts_1' => @tariff_record_2.hts_1.hts_format}
              ]
            }
          ]
        }
      }
      expect(ActiveSupport::JSON.decode(json)).to eq hash
    end

    it 'skips levels that did not have model fields requested for them' do
      json = OpenChain::Api::ApiEntityJsonizer.new.entity_to_json @user, @product, ['prod_uid', 'class_cntry_iso']
      hash = {
        'product' => {
          'id' => @product.id,
          'prod_uid'=> @product.unique_identifier,
          'classifications' => [
            {
              "class_cntry_iso" => @country_1.iso_code, 
            },
            {
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
              "tariff_records" => [
                {'hts_hts_1' => @tariff_record.hts_1.hts_format}
              ]
            },
            {
              "tariff_records" => [
                {'hts_hts_1' => @tariff_record_2.hts_1.hts_format}
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
              'ci_total_quantity_uom' => nil,
              'commercial_invoice_lines' => [
                {'cil_po_number' => nil}
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
                "*cf_#{@c_def.id}" => Date.new(2013, 12, 20).to_s, 
                "tariff_records" => [
                  {"*cf_#{@t_def.id}" => BigDecimal.new("10.99").to_s}
                ]
              },
              {
                "*cf_#{@c_def.id}" => nil, 
                "tariff_records" => [
                  {"*cf_#{@t_def.id}" => nil}
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

      cm_fields = CoreModule::PRODUCT.model_fields @user
      expect(model_fields['product']).to have(cm_fields.size).items
      expect(model_fields['classifications']).to have(CoreModule::CLASSIFICATION.model_fields(@user).size).items
      expect(model_fields['tariff_records']).to have(CoreModule::TARIFF.model_fields(@user).size).items

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
      expect(model_fields['classifications']).to be_nil
      expect(model_fields['tariff_records']).to be_nil
    end
  end
end 