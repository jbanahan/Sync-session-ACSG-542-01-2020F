describe ProductsController do
  before :each do

    @user = FactoryBot(:importer_user, :product_edit=>true, :product_view=>true, :classification_edit=>true)
    @other_importer = FactoryBot(:company, :importer=>true)
    @linked_importer = FactoryBot(:company, :importer=>true)
    @user.company.linked_companies << @linked_importer
    sign_in_as @user
  end
  describe "next" do
    it "should go to next item" do
      p = FactoryBot(:product)
      expect_any_instance_of(ResultCache).to receive(:next).with(99).and_return(p.id)
      ss = FactoryBot(:search_setup, :user=>@user, :module_type=>"Product")
      ss.touch # makes underlying search run
      get :next_item, :id=>"99"
      expect(response).to redirect_to "/products/#{p.id}"
    end
    it "should redirect to referrer and show error if result cache return nil" do
      expect_any_instance_of(ResultCache).to receive(:next).with(99).and_return(nil)
      ss = FactoryBot(:search_setup, :user=>@user, :module_type=>"Product")
      ss.touch # makes underlying search run
      get :next_item, :id=>"99"
      expect(response).to redirect_to request.referrer
      expect(flash[:errors].first).to eq "Next object could not be found."
    end
  end
  describe "previous" do
    it "should go to the previous item" do
      p = FactoryBot(:product)
      expect_any_instance_of(ResultCache).to receive(:previous).with(99).and_return(p.id)
      ss = FactoryBot(:search_setup, :user=>@user, :module_type=>"Product")
      ss.touch # makes underlying search run
      get :previous_item, :id=>"99"
      expect(response).to redirect_to "/products/#{p.id}"
    end
    it "should redirect to referrer and show error if result cache return nil" do
      expect_any_instance_of(ResultCache).to receive(:previous).with(99).and_return(nil)
      ss = FactoryBot(:search_setup, :user=>@user, :module_type=>"Product")
      ss.touch # makes underlying search run
      get :previous_item, :id=>"99"
      expect(response).to redirect_to request.referrer
      expect(flash[:errors].first).to eq "Previous object could not be found."
    end
  end
  describe "create" do
    it "should fail if not master and importer_id is not current company or linked company" do
      post :create, 'product'=>{'prod_uid'=>'abc123455_pccreate', 'prod_imp_id'=>@other_importer.id}
      expect(flash[:errors].first).to eq("You do not have permission to set Importer Name to company #{@other_importer.name}")
    end
    it "should pass if importer_id is current company" do
      post :create, 'product'=>{'prod_uid'=>'abc123455_pccreate', 'prod_imp_id'=>@user.company.id}
      p = Product.first
      expect(p.unique_identifier).to eq "abc123455_pccreate"
      expect(p.importer).to eq @user.company
    end
    it "should pass if importer_id is linked company" do
      post :create, 'product'=>{'prod_uid'=>'abc123455_pccreate', 'prod_imp_id'=>@linked_importer.id}
      p = Product.first
      expect(p.unique_identifier).to eq "abc123455_pccreate"
      expect(p.importer).to eq @linked_importer
    end
  end
  describe "update" do
    before :each do
      @product = FactoryBot(:product, :importer=>@user.company)
    end
    it "should fail if not master and importer_id is not current company or linked company" do
      put :update, 'id'=>@product.id, 'product'=>{'prod_uid'=>'abc123455_pccreate', 'prod_imp_id'=>@other_importer.id}
      expect(flash[:errors]).to include "You do not have permission to set Importer Name to company #{@other_importer.name}"
    end
    it "should pass if importer_id is linked company" do
      put :update, 'id'=>@product.id, 'product'=>{'prod_uid'=>'abc123455_pccreate', 'prod_imp_id'=>@linked_importer.id}
      p = Product.find @product.id
      expect(p.unique_identifier).to eq "abc123455_pccreate"
      expect(p.importer).to eq @linked_importer
    end
    it "should pass if importer_id is current company" do
      put :update, 'id'=>@product.id, 'product'=>{'prod_uid'=>'abc123455_pccreate', 'prod_imp_id'=>@user.company.id}
      p = Product.find @product.id
      expect(p.unique_identifier).to eq "abc123455_pccreate"
      expect(p.importer).to eq @user.company
    end
    it "should clear custom value at classification level" do
      cntry = FactoryBot(:country)
      cls = FactoryBot(:classification, product:@product, country:cntry)
      cd = FactoryBot(:custom_definition, module_type:'Classification', data_type:'string')
      cls.update_custom_value!(cd, 'abc')
      put :update, id:@product.id, 'product'=>{'prod_uid'=>'1234', 'classifications_attributes'=>{'0'=>{'id'=>cls.id.to_s, 'class_cntry_id' => cntry.id.to_s, cd.model_field_uid.to_s => ''}}}
      p = Product.find @product.id
      expect(p.classifications.first.get_custom_value(cd).value).to be_blank
    end
  end

  describe "bulk_update" do
    it "should bulk update inline for less than 10 products" do
      expect(OpenChain::BulkUpdateClassification).to receive(:bulk_update) do |params, user, opts|
        expected = {"us" => "1"}
        expect(params['product']['classifications_attributes']).to eq expected
        expect(user.id).to eq @user.id
        expect(opts[:no_user_message]).to be_truthy

        expect(params[:product][:unique_identifier]).to be_nil
        expect(params[:product][:id]).to be_nil
        expect(params[:product][:field2]).to be_nil
        expect(params[:utf8]).to be_nil
        expect(params[:pk]["0"]).to eq "0"
        expect(params[:pk]["9"]).to eq "9"

        {:message => "Test", :errors => ["1", "2"]}
      end
      # Several fields are not allowed to be bulk updated (as well as blank values)
      p = {:product => {:field => "value", :unique_identifier => "v", :id=>"id", :field2 => '', :classifications_attributes=>{"us"=>"1"}}, :utf8 => 'v'}
      pks = {}
      (0..9).each do |i|
        pks[i.to_s] = i.to_s
      end
      p[:pk] = pks

      post :bulk_update, p
      expect(response).to redirect_to controller.advanced_search(CoreModule::PRODUCT, false, true)
      expect(flash[:notices].first).to eq "Test"
      expect(flash[:errors][0]).to eq "1"
      expect(flash[:errors][1]).to eq "2"
    end

    it "should delay bulk updates with over 10 keys" do
      p = {:product => {:field => "value"}}
      pks = {}
      (0..10).each do |i|
        pks[i.to_s] = i.to_s
      end
      p[:pk] = pks

      expect(OpenChain::BulkUpdateClassification).to receive(:delayed_bulk_update) do |params, user|
        expect(user).to eq @user
        expect(params['pk'].length).to eq 11
        expect(params['product']['field']).to eq "value"
      end

      post :bulk_update, p
      expect(response).to redirect_to controller.advanced_search(CoreModule::PRODUCT, false, true)
      expect(flash[:notices].first).to eq "These products will be updated in the background.  You will receive a system message when they're ready."
    end

    it "should delay bulk updates for search runs" do
      p = {:product => {:field => "value"}, :sr_id => 1, :pk => {"0" => "0"}}

      expect(OpenChain::BulkUpdateClassification).to receive(:delayed_bulk_update) do |params, user|
        expect(user).to eq @user
        expect(params['sr_id']).to eq "1"
        expect(params['product']['field']).to eq "value"
      end

      post :bulk_update, p
      expect(response).to redirect_to controller.advanced_search(CoreModule::PRODUCT, false, true)
      expect(flash[:notices].first).to eq "These products will be updated in the background.  You will receive a system message when they're ready."
    end
  end

  describe "bulk_update_classifications" do
    it "should run delayed for search runs" do
      p = {:sr_id=>1}

      b = double
      expect(OpenChain::BulkUpdateClassification).to receive(:delayed_quick_classify) do |params, id|
        expect(id).to eq @user
        expect(params["sr_id"]).to eq "1"
      end

      post :bulk_update_classifications, p
      expect(response).to redirect_to Product
      expect(flash[:notices].first).to eq "These products will be updated in the background.  You will receive a system message when they're ready."
    end

    it "should run delayed for more than 10 products" do
      pks = {}
      (0..10).each do |i|
        pks[i.to_s] = i.to_s
      end
      p = {:pk => pks}

      expect(OpenChain::BulkUpdateClassification).to receive(:delayed_quick_classify) do |params, id|
        expect(id).to eq @user
        expect(params["pk"].length).to eq 11
      end

      post :bulk_update_classifications, p
      expect(response).to redirect_to Product
      expect(flash[:notices].first).to eq "These products will be updated in the background.  You will receive a system message when they're ready."
    end

    it "should not run delayed for 10 products" do
      pks = {}
      (0..9).each do |i|
        pks[i.to_s] = i.to_s
      end
      p = {:pk => pks}
      b = BulkProcessLog.create!
      expect(OpenChain::BulkUpdateClassification).to receive(:quick_classify) do |params, u, options|
        expect(u).to eq @user
        expect(params[:pk].length).to eq 10
        expect(options[:no_user_message]).to be_truthy
        b
      end

      post :bulk_update_classifications, p
      expect(response).to redirect_to products_path
    end

    it "should allow user to bulk update classifications" do
      p = {"k1"=>"v1", "k2"=>"v2", :sr_id=>"1"}
      expect(OpenChain::BulkUpdateClassification).to receive(:delayed_quick_classify) do |params, id|
        expect(params["k1"]).to eq "v1"
        expect(params["k2"]).to eq "v2"
        expect(id).to eq @user
      end

      request.env["HTTP_REFERER"] = "http://www.test.com?force_search=true&key=val"
      post :bulk_update_classifications, p
      expect(flash[:notices]).to eq ["These products will be updated in the background.  You will receive a system message when they're ready."]
      expect(response).to redirect_to Product
    end

    it "should redirect to products_path with no referer" do
      p = {:sr_id => "1"}
      expect(OpenChain::BulkUpdateClassification).to receive(:delayed_quick_classify)
      request.env["HTTP_REFERER"] = nil
      post :bulk_update_classifications, p
      expect(response).to redirect_to(products_path)
    end

    it "should redirect to 'back_to' parameter if set" do
      request.env["HTTP_REFERER"] = "http://www.test.com?force_search=true&key=x"
      expect(OpenChain::BulkUpdateClassification).to receive(:delayed_quick_classify)
      post :bulk_update_classifications, {'back_to'=>'/somewhere?force_search=true&key=val', :sr_id=>"1"}
      expect(response).to redirect_to("http://test.host/somewhere?key=val")
    end
  end

  describe "show_region_modal" do
    let!(:c1) { FactoryBot(:country, iso_code: "US", name: "United States") }
    let!(:c2) { FactoryBot(:country, iso_code: "CA", name: "Canada") }
    let!(:c3) { FactoryBot(:country, iso_code: "CN", name: "China") }
    let!(:region) { FactoryBot(:region, name: "N. America", countries: [c1, c2]) }
    let!(:region_2) { FactoryBot(:region, name: "Asia", countries: [c3])}

    it "renders for user who can edit classifications" do
      get :show_region_modal, country_ids: "#{c2.id}, #{c1.id}"
      expect(assigns(:countries)).to eq [{id: c2.id, name: "Canada"}, {id: c1.id, name: "United States"}]
      expect(assigns(:regions)).to eq({region.id => {country_ids: [c2.id, c1.id], name: "N. America"}})
      expect(response).to be_ok
    end

    it "redirects otherwise" do
      @user.classification_edit = false; @user.save!
      get :show_region_modal, country_ids: "#{c1.id}, #{c2.id}"
      expect(response).to be_redirect
      expect(flash[:errors]).to eq ["You do not have permission to edit classifications"]
    end
  end
end
