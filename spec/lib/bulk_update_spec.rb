describe OpenChain::BulkUpdateClassification do
  describe "go" do
    before :each do
      ModelField.reload # cleanup from other tests
      @ms = MasterSetup.new :request_host => "localhost"
      allow(MasterSetup).to receive(:get).and_return @ms
      @u = create(:user, :company=>create(:company, :master=>true), :product_edit=>true, :classification_edit=>true)
      @p = create(:product, :unit_of_measure=>"UOM")
      @country = create(:country)
      @h = {"pk"=>{ "1"=>@p.id.to_s }, "product"=>{"classifications_attributes"=>{"0"=>{"class_cntry_id"=>@country.id.to_s}}}}
    end

    context "can_classify" do
      before :each do
        allow_any_instance_of(Product).to receive(:can_classify?).and_return true
      end

      it "should update an existing classification with primary keys" do
        m = OpenChain::BulkUpdateClassification.bulk_update(@h, @u)
        expect(Product.find(@p.id).classifications.size).to eq(1)

        log = BulkProcessLog.first
        expect(log.total_object_count).to eq 1
        expect(log.changed_object_count).to eq 1
        expect(log.change_records.size).to eq(1)
        expect(log.change_records.first.failed).to be_falsey
        expect(log.change_records.first.entity_snapshot).not_to be_nil

        expect(@u.messages.length).to eq(1)
        expect(@u.messages[0].subject).to eq("Bulk Update Job Complete.")
        expect(@u.messages[0].body).to eq("<p>Your Bulk Update job has completed.</p><p>1 Product saved.</p><p>The full update log is available <a href=\"https://#{@ms.request_host}/bulk_process_logs/#{log.id}\">here</a>.</p>")
        expect(m[:message]).to eq("Bulk Update Job Complete.")
        expect(m[:errors]).to eq([])
        expect(m[:good_count]).to eq(1)
      end
      it "should record validation errors in update log and messages" do
        # Create field validator rule to reject on
        FieldValidatorRule.create! starts_with: "A", module_type: "Product", model_field_uid: "prod_uid"

        @h['product']['prod_uid'] = 'BBB'
        m = OpenChain::BulkUpdateClassification.bulk_update(@h, @u)

        log = BulkProcessLog.first
        expect(log.total_object_count).to eq 1
        expect(log.changed_object_count).to eq 0
        expect(log.change_records.size).to eq(1)
        expect(log.change_records.first.failed).to be_truthy
        expect(log.change_records.first.entity_snapshot).to be_nil
        expect(log.change_records.first.messages[0]).to match /^Error saving product/

        expect(@u.messages.length).to eq(1)
        expect(@u.messages[0].subject).to eq("Bulk Update Job Complete (1 Error).")
        expect(@u.messages[0].body).to eq("<p>Your Bulk Update job has completed.</p><p>0 Products saved.</p><p>The full update log is available <a href=\"https://#{@ms.request_host}/bulk_process_logs/#{log.id}\">here</a>.</p>")
        expect(m[:message]).to eq("Bulk Update Job Complete (1 Error).")
        expect(m[:errors][0]).to match /^Error saving product/
        expect(m[:good_count]).to eq(0)
      end
      it "should update but not make user messages" do
        OpenChain::BulkUpdateClassification.bulk_update(@h, @u, :no_user_message => true)
        expect(Product.find(@p.id).classifications.size).to eq(1)
        expect(@u.messages.length).to eq(0)
      end
      it "creates new classification and tariff records" do
        create(:official_tariff, :country=>@country, :hts_code=>'1234567890')
        class_cd = create(:custom_definition, :module_type=>'Classification', :data_type=>:string)
        tr_cd = create(:custom_definition, :module_type=>'TariffRecord', :data_type=>:string)
        prod_cd = create(:custom_definition, :module_type=>'Product', :data_type=>:string)

        @h['product']['classifications_attributes']['0']['tariff_records_attributes'] = {'0'=>{'hts_hts_1' => '1234567890', 'hts_view_sequence'=>'987654321', tr_cd.model_field_uid.to_s => 'DEF'}}
        @h['product']['classifications_attributes']['0']['class_cntry_id'] = @country.id.to_s
        @h['product']['classifications_attributes']['0'][class_cd.model_field_uid.to_s] = 'ABC'

        # Set a product value and a product custom value to make sure they're also being set
        @h['product']['prod_uom'] = "UOM"
        @h['product'][prod_cd.model_field_uid.to_s] = "PROD_UPDATE"

        OpenChain::BulkUpdateClassification.bulk_update(@h, @u)
        @p.reload

        expect(@p.unit_of_measure).to eq("UOM")
        expect(@p.get_custom_value(prod_cd).value).to eq("PROD_UPDATE")

        cls = @p.classifications.first
        expect(cls.country_id).to eq(@country.id)
        expect(cls.get_custom_value(class_cd).value).to eq('ABC')
        expect(cls.tariff_records.first.line_number).to eq(1)
        expect(cls.tariff_records.first.hts_1).to eq('1234567890')
        expect(cls.tariff_records.first.get_custom_value(tr_cd).value).to eq('DEF')
      end

      it "does not use blank attributes and custom values from product, classification, and tariff parameters" do
        create(:official_tariff, :country=>@country, :hts_code=>'1234567890')
        class_cd = create(:custom_definition, :module_type=>'Classification', :data_type=>:string)
        tr_cd = create(:custom_definition, :module_type=>'TariffRecord', :data_type=>:string)
        prod_cd = create(:custom_definition, :module_type=>'Product', :data_type=>:string)
        tr = create(:tariff_record, :hts_2=>'1234567890', :classification=>create(:classification, :country=>@country, :product=>@p))
        tr.update_custom_value! tr_cd, 'DEF'
        classification = tr.classification
        classification.update_custom_value! class_cd, 'ABC'
        @p.update_custom_value! prod_cd, "PROD"

        @h['classification_custom'] = {'0'=>{'classification_cf'=>{class_cd.id.to_s => ''}}} # blank classification shouldn't clear
        @h['tariff_custom'] = {'1' => {'tariffrecord_cf' => {tr_cd.id.to_s => ''}}} # blank tariff shouldn't clear
        @h['product']['classifications_attributes']['0']['class_cntry_id'] = classification.country.id.to_s
        @h['product']['classifications_attributes']['0'][class_cd.model_field_uid.to_s] = ''
        @h['product']['classifications_attributes']['0']['tariff_records_attributes'] = {'0'=>{'hts_hts_1' => '1234567890', 'hts_hts_2' => ''}}
        # Set a product value and a product custom value to make sure they're also being set
        @h['product']['prod_uom'] = ""
        @h['product'][prod_cd.model_field_uid.to_s] = ""
        OpenChain::BulkUpdateClassification.bulk_update(@h, @u)
        @p.reload

        # Validate product level blank attributes / custom values aren't used
        expect(@p.unit_of_measure).to eq("UOM")
        expect(@p.get_custom_value(prod_cd).value).to eq("PROD")

        cls = @p.classifications.first

        # Make sure we're updating the same actual classification and tariff records and not tearing down and rebuilding them
        expect(cls.id).to eq(classification.id)
        expect(cls.get_custom_value(class_cd).value).to eq('ABC')
        expect(cls.tariff_records.first.id).to eq(tr.id)
        expect(cls.tariff_records.first.hts_1).to eq('1234567890')
        expect(cls.tariff_records.first.hts_2).to eq('1234567890')
        expect(cls.tariff_records.first.get_custom_value(tr_cd).value).to eq('DEF')
      end

      it "should allow override of classification & tariff custom values" do
        create(:official_tariff, :country=>@country, :hts_code=>'1234567890')
        class_cd = create(:custom_definition, :module_type=>'Classification', :data_type=>:string)
        tr_cd = create(:custom_definition, :module_type=>'TariffRecord', :data_type=>:string)
        tr = create(:tariff_record, :classification=>create(:classification, :country=>@country, :product=>@p))
        tr.update_custom_value! tr_cd, 'DEF'
        cls = tr.classification
        cls.update_custom_value! class_cd, 'ABC'
        @h['product']['classifications_attributes']['0']['tariff_records_attributes'] = {'0'=>{'hts_hts_1' => '1234567890', 'hts_view_sequence'=>'1', 'hts_line_number'=>'1', tr_cd.model_field_uid.to_s => 'TAROVR'}}
        @h['product']['classifications_attributes']['0'][class_cd.model_field_uid.to_s] = 'CLSOVR'
        OpenChain::BulkUpdateClassification.bulk_update(@h, @u)
        @p.reload
        expect(@p.classifications.first.tariff_records.first.hts_1).to eq('1234567890')
        cls = @p.classifications.first
        expect(cls.get_custom_value(class_cd).value).to eq('CLSOVR')
        expect(cls.tariff_records.first.get_custom_value(tr_cd).value).to eq('TAROVR')
      end

      it "skips classification and tariff values without overwriting them when no classification parameters are sent" do
        create(:official_tariff, :country=>@country, :hts_code=>'1234567890')
        class_cd = create(:custom_definition, :module_type=>'Classification', :data_type=>:string)
        tr_cd = create(:custom_definition, :module_type=>'TariffRecord', :data_type=>:string)
        prod_cd = create(:custom_definition, :module_type=>'Product', :data_type=>:string)
        tr = create(:tariff_record, :hts_1=>'1234567890', :classification=>create(:classification, :country=>@country, :product=>@p))
        tr.update_custom_value! tr_cd, 'DEF'
        cls = tr.classification
        cls.update_custom_value! class_cd, 'ABC'
        @p.update_custom_value! prod_cd, "PROD"

        @h['product'].delete 'classifications_attributes'
        @h['product']['prod_uom'] = "UOM"
        @h['product'][prod_cd.model_field_uid.to_s] = "PROD_UPDATE"
        OpenChain::BulkUpdateClassification.bulk_update(@h, @u)
        @p.reload

        expect(@p.unit_of_measure).to eq("UOM")
        expect(@p.get_custom_value(prod_cd).value).to eq("PROD_UPDATE")

        expect(@p.classifications.first.tariff_records.first.hts_1).to eq('1234567890')
        cls = @p.classifications.first
        expect(cls.get_custom_value(class_cd).value).to eq('ABC')
        expect(cls.tariff_records.first.get_custom_value(tr_cd).value).to eq('DEF')
      end

      it 'uses tariff line number, when present, to identify which tariff record to update' do
        create(:official_tariff, :country=>@country, :hts_code=>'1234567890')
        create(:official_tariff, :country=>@country, :hts_code=>'9876543210')
        tr = create(:tariff_record, :hts_1=>'1234567890', :line_number => 1, :classification=>create(:classification, :country=>@country, :product=>@p))
        tr2 = create(:tariff_record, :hts_1=>'9876543210', :line_number => 2, :classification=>tr.classification)

        # Note the long index value for the second tariff line, this is how the screen effectively sends updates when the users adds second hts lines on the bulk screen
        @h['product']['classifications_attributes']['0']['tariff_records_attributes'] = {'0'=>{'hts_hts_1' => '1234567890', 'hts_view_sequence'=>'0', 'hts_line_number'=>'2'}, '1234567890'=>{'hts_hts_1' => '9876543210', 'hts_view_sequence'=>'1234567890', 'hts_line_number'=>'1'}}

        OpenChain::BulkUpdateClassification.bulk_update(@h, @u)
        @p.reload

        expect(@p.classifications.first.tariff_records.second.line_number).to eq 2
        expect(@p.classifications.first.tariff_records.first.hts_1).to eq '9876543210'
        expect(@p.classifications.first.tariff_records.second.hts_1).to eq '1234567890'
      end

      it 'does not remove existing tariff lines if updating only the first tariff record in a set' do
        create(:official_tariff, :country=>@country, :hts_code=>'1234567890')
        create(:official_tariff, :country=>@country, :hts_code=>'9876543210')
        tr = create(:tariff_record, :hts_1=>'1234567890', :line_number => 1, :classification=>create(:classification, :country=>@country, :product=>@p))
        tr2 = create(:tariff_record, :hts_1=>'9876543210', :line_number => 2, :classification=>tr.classification)

        @h['product']['classifications_attributes']['0']['tariff_records_attributes'] = {'0'=>{'hts_hts_1' => '9876543210', 'hts_view_sequence'=>'0'}}

        OpenChain::BulkUpdateClassification.bulk_update(@h, @u)
        @p.reload

        expect(@p.classifications.first.tariff_records.size).to eq(2)
        expect(@p.classifications.first.tariff_records.first.line_number).to eq 1
        expect(@p.classifications.first.tariff_records.first.hts_1).to eq '9876543210'
      end

      it 'does not remove existing tariff lines if updating only the second tariff record in a set' do
        create(:official_tariff, :country=>@country, :hts_code=>'1234567890')
        create(:official_tariff, :country=>@country, :hts_code=>'9876543210')
        create(:official_tariff, :country=>@country, :hts_code=>'1111111111')
        tr = create(:tariff_record, :hts_1=>'1234567890', :line_number => 1, :classification=>create(:classification, :country=>@country, :product=>@p))
        tr2 = create(:tariff_record, :hts_1=>'9876543210', :line_number => 2, :classification=>tr.classification)

        @h['product']['classifications_attributes']['0']['tariff_records_attributes'] = {'0'=>{'hts_hts_1' => '1111111111', 'hts_view_sequence'=>'0', 'hts_line_number'=>'2'}}

        OpenChain::BulkUpdateClassification.bulk_update(@h, @u)
        @p.reload

        expect(@p.classifications.first.tariff_records.size).to eq(2)
        expect(@p.classifications.first.tariff_records.first.line_number).to eq 1
        expect(@p.classifications.first.tariff_records.first.hts_1).to eq '1234567890'
        expect(@p.classifications.first.tariff_records.second.hts_1).to eq '1111111111'
      end
    end

    it "errors if user cannot classify" do
      allow_any_instance_of(Product).to receive(:can_classify?).and_return false

      m = OpenChain::BulkUpdateClassification.bulk_update(@h, @u)
      expect(m[:errors].size).to eq(1)

      expect(m[:errors].first).to eq "You do not have permission to classify product #{@p.unique_identifier}."
    end

    it "errors if user cannot edit products" do
      allow_any_instance_of(Product).to receive(:can_edit?).and_return false

      m = OpenChain::BulkUpdateClassification.bulk_update(@h, @u)
      expect(m[:errors].size).to eq(1)

      expect(m[:errors].first).to eq "You do not have permission to edit product #{@p.unique_identifier}."
    end

    it "does not error if user can edit but cannot classify if there are no classification attributes" do
      allow_any_instance_of(Product).to receive(:can_edit?).and_return true
      allow_any_instance_of(Product).to receive(:can_classify?).and_return false

      @h['product'].delete 'classifications_attributes'
      @h['product']['unit_of_measure'] = "UOM"

      OpenChain::BulkUpdateClassification.bulk_update(@h, @u)
      @p.reload

      expect(@p.unit_of_measure).to eq("UOM")
    end

  end
  describe 'build_common_classifications' do
    before :each do
      @products = 2.times.collect {create(:product)}
      @country = create(:country)
      @hts = '1234567890'
      @products.each do |p|
        p.classifications.create!(:country_id=>@country.id).tariff_records.create!(:line_number=>1, :hts_1=>@hts)
      end
      @base_product = Product.new
    end
    it "should build tariff based on primary keys" do
      product_ids = @products.collect {|p| p.id}
      OpenChain::BulkUpdateClassification.build_common_classifications product_ids, @base_product
      expect(@base_product.classifications.size).to eq(1)
      classification = @base_product.classifications.first
      expect(classification.country).to eq(@country)
      expect(classification.tariff_records.size).to eq(1)
      tr = classification.tariff_records.first
      expect(tr.hts_1).to eq(@hts)
      expect(tr.line_number).to eq(1)
    end
    it "should build tariff based on search run" do
      user = create(:user, :admin=>true, :company_id=>create(:company, :master=>true).id)
      search_setup = create(:search_setup, :module_type=>"Product", :user=>user)
      search_setup.touch # makes search_run
      OpenChain::BulkUpdateClassification.build_common_classifications search_setup.search_runs.first, @base_product
      expect(@base_product.classifications.size).to eq(1)
      classification = @base_product.classifications.first
      expect(classification.country).to eq(@country)
      expect(classification.tariff_records.size).to eq(1)
      tr = classification.tariff_records.first
      expect(tr.hts_1).to eq(@hts)
      expect(tr.line_number).to eq(1)
    end
    it "should build for one country and not for another when the second has different tariffs" do
      country_2 = create(:country)
      @products.each_with_index do |p, i|
        p.classifications.create!(:country_id=>country_2.id).tariff_records.create!(:line_number=>1, :hts_1=>"123456789#{i}")
      end
      product_ids = @products.collect {|p| p.id}
      OpenChain::BulkUpdateClassification.build_common_classifications product_ids, @base_product
      expect(@base_product.classifications.size).to eq(1)
      classification = @base_product.classifications.first
      expect(classification.country).to eq(@country)
      expect(classification.tariff_records.size).to eq(1)
      tr = classification.tariff_records.first
      expect(tr.hts_1).to eq(@hts)
      expect(tr.line_number).to eq(1)
    end
    it "should not build if one of the products does not have the classification for the country" do
      country_2 = create(:country)
      @products.first.classifications.create!(:country_id=>country_2.id).tariff_records.create!(:line_number=>1, :hts_1=>"123456789")
      product_ids = @products.collect {|p| p.id}
      OpenChain::BulkUpdateClassification.build_common_classifications product_ids, @base_product
      expect(@base_product.classifications.size).to eq(1)
      classification = @base_product.classifications.first
      expect(classification.country).to eq(@country)
      expect(classification.tariff_records.size).to eq(1)
      tr = classification.tariff_records.first
      expect(tr.hts_1).to eq(@hts)
      expect(tr.line_number).to eq(1)
    end
  end

  describe "quick_classify" do
    before :each do
      @u = create(:user, :company=>create(:company, :master=>true), :product_edit=>true, :classification_edit=>true, :product_view=> true)
      @country = create(:country, :iso_code => "US")
      @products = [create(:product, classifications: [create(:classification, country: @country)]),
                   create(:product)]
      @ms = MasterSetup.new :request_host => "localhost"
      allow(MasterSetup).to receive(:get).and_return @ms

      @hts = '1234567890'
      @parameters = {
        'pk' => ["#{@products[0].id}", "#{@products[1].id}"],
        'product' => {
            'classifications_attributes' => {
              @country.id.to_s => {
                  'class_cntry_id' => "#{@country.id}",
                  'tariff_records_attributes' => {
                      "1" => {
                        "hts_hts_1" => @hts,
                        "line_number" => "1"
                      }
                  }
              }
            }
        }
      }
    end

    it "should create new classifications on products" do
      log = OpenChain::BulkUpdateClassification.quick_classify @parameters, @u

      @products.each do |p|
        p.reload

        expect(p.classifications.size).to eq(1)
        expect(p.classifications[0].country_id).to eq @country.id

        expect(p.classifications[0].tariff_records.size).to eq(1)
        expect(p.classifications[0].tariff_records[0].hts_1).to eq @hts
      end

      expect(log.change_records.size).to eq(2)
      log.change_records.each do |cr|
        expect(cr.entity_snapshot).not_to be_nil
      end

      expect(@u.messages.size).to eq(1)
      expect(@u.messages[0].subject).to eq "Bulk Classify Job Complete."
      expect(@u.messages[0].body).to eq "<p>Your Bulk Classify job has completed.</p><p>2 Products saved.</p><p>The full update log is available <a href=\"https://#{@ms.request_host}/bulk_process_logs/#{log.id}\">here</a>.</p>"
    end

    it "should create new classifications on products using json string" do
      OpenChain::BulkUpdateClassification.quick_classify @parameters.to_json, @u

      @products.each do |p|
        p.reload
        expect(p.classifications.size).to eq(1)
        expect(p.classifications[0].country_id).to eq @country.id

        expect(p.classifications[0].tariff_records.size).to eq(1)
        expect(p.classifications[0].tariff_records[0].hts_1).to eq @hts
      end
    end

    it "does not add custom value even if there is one present in the parameters" do
      class_cd = create(:custom_definition, :module_type=>'Classification', :data_type=>:string)
      @parameters['product']['classifications_attributes'][@country.id.to_s][class_cd.model_field_uid.to_s] = 'VALUE'

      OpenChain::BulkUpdateClassification.quick_classify @parameters.to_json, @u

      @products.each do |p|
        p.reload

        expect(p.classifications.first.get_custom_value(class_cd).value).to be_nil
      end
    end

    it "should update existing classification and tariff records on a product" do
      p = @products[0]
      p.classifications.first.tariff_records.create! hts_1: "75315678", line_number: 1

      @parameters['pk'] = ["#{@products[0].id}"]
      @parameters['product']['classifications_attributes'][@country.id.to_s]["id"] = "#{p.classifications[0].id}"
      @parameters['product']['classifications_attributes'][@country.id.to_s]["tariff_records_attributes"]["1"]["id"] = "#{p.classifications[0].tariff_records[0].id}"
      @parameters['product']['classifications_attributes'][@country.id.to_s]["tariff_records_attributes"]["2"] = {"hts_hts_1" => "0101301234", "line_number" => "2" }

      messages = OpenChain::BulkUpdateClassification.quick_classify @parameters, @u

      p.reload
      expect(p.classifications.size).to eq(1)
      expect(p.classifications[0].country_id).to eq @country.id

      expect(p.classifications[0].tariff_records.size).to eq(2)
      expect(p.classifications[0].tariff_records[0].hts_1).to eq @hts
      expect(p.classifications[0].tariff_records[1].hts_1).to eq "0101301234"
    end

    it "should handle errors in product updates" do
      # An easy way to force an error is to set the value to blank
      allow(OpenChain::FieldLogicValidator).to receive(:validate) do |o|
        o.errors[:base] << "Error"
        raise OpenChain::ValidationLogicError.new nil, o
      end
      p = @products[0]
      @parameters['pk'] = ["#{@products[0].id}"]

      log = OpenChain::BulkUpdateClassification.quick_classify @parameters, @u

      expect(log.change_records.size).to eq(1)
      expect(log.change_records.first.failed).to be_truthy
      expect(log.change_records.first.messages[0]).to eq "Error saving product #{p.unique_identifier}: Error"
      expect(log.change_records.first.entity_snapshot).to be_nil

      expect(@u.messages.size).to eq(1)
      expect(@u.messages[0].subject).to eq "Bulk Classify Job Complete (1 Error)."
      expect(@u.messages[0].body).to eq "<p>Your Bulk Classify job has completed.</p><p>0 Products saved.</p><p>The full update log is available <a href=\"https://#{@ms.request_host}/bulk_process_logs/#{log.id}\">here</a>.</p>"

    end

    it "should verify user can classify product" do
      p = @products[0]
      @parameters['pk'] = ["#{@products[0].id}"]

      @u.update_attributes product_view: false
      log = OpenChain::BulkUpdateClassification.quick_classify @parameters, @u

      expect(@u.messages.size).to eq(1)
      expect(@u.messages[0].subject).to eq "Bulk Classify Job Complete (1 Error)."

    end

    it "should not log user messages if specified" do
      p = @products[0]
      @parameters['pk'] = ["#{@products[0].id}"]

      @u.update_attributes product_view: false
      messages = OpenChain::BulkUpdateClassification.quick_classify @parameters, @u, no_user_message: true

      expect(@u.messages.size).to eq(0)
    end
  end
end
