require 'spec_helper'

describe ProductsController do
  before :each do

    @user = Factory(:importer_user,:product_edit=>true,:product_view=>true,:classification_edit=>true)
    @other_importer = Factory(:company,:importer=>true)
    @linked_importer = Factory(:company,:importer=>true)
    @user.company.linked_companies << @linked_importer
    sign_in_as @user
  end
  describe :next do
    it "should go to next item" do
      p = Factory(:product)
      ResultCache.any_instance.should_receive(:next).with(99).and_return(p.id)
      ss = Factory(:search_setup,:user=>@user,:module_type=>"Product")
      ss.touch #makes underlying search run
      get :next_item, :id=>"99"
      response.should redirect_to "/products/#{p.id}"
    end
    it "should redirect to referrer and show error if result cache return nil" do
      ResultCache.any_instance.should_receive(:next).with(99).and_return(nil)
      ss = Factory(:search_setup,:user=>@user,:module_type=>"Product")
      ss.touch #makes underlying search run
      get :next_item, :id=>"99"
      response.should redirect_to request.referrer
      flash[:errors].first.should == "Next object could not be found."
    end
  end
  describe :previous do
    it "should go to the previous item" do
      p = Factory(:product)
      ResultCache.any_instance.should_receive(:previous).with(99).and_return(p.id)
      ss = Factory(:search_setup,:user=>@user,:module_type=>"Product")
      ss.touch #makes underlying search run
      get :previous_item, :id=>"99"
      response.should redirect_to "/products/#{p.id}"
    end
    it "should redirect to referrer and show error if result cache return nil" do
      ResultCache.any_instance.should_receive(:previous).with(99).and_return(nil)
      ss = Factory(:search_setup,:user=>@user,:module_type=>"Product")
      ss.touch #makes underlying search run
      get :previous_item, :id=>"99"
      response.should redirect_to request.referrer
      flash[:errors].first.should == "Previous object could not be found."
    end
  end
  describe :create do
    it "should fail if not master and importer_id is not current company or linked company" do
      post :create, 'product'=>{'prod_uid'=>'abc123455_pccreate','prod_imp_id'=>@other_importer.id}
      flash[:errors].first.should == "You do not have permission to set Importer Name to company #{@other_importer.name}"
    end
    it "should pass if importer_id is current company" do
      post :create, 'product'=>{'prod_uid'=>'abc123455_pccreate','prod_imp_id'=>@user.company.id}
      p = Product.first
      p.unique_identifier.should == "abc123455_pccreate"
      p.importer.should == @user.company
    end
    it "should pass if importer_id is linked company" do
      post :create, 'product'=>{'prod_uid'=>'abc123455_pccreate','prod_imp_id'=>@linked_importer.id}
      p = Product.first
      p.unique_identifier.should == "abc123455_pccreate"
      p.importer.should == @linked_importer
    end
  end
  describe :update do
    before :each do 
      @product = Factory(:product,:importer=>@user.company)
    end
    it "should fail if not master and importer_id is not current company or linked company" do
      put :update, 'id'=>@product.id, 'product'=>{'prod_uid'=>'abc123455_pccreate','prod_imp_id'=>@other_importer.id}
      flash[:errors].should include "You do not have permission to set Importer Name to company #{@other_importer.name}"
    end
    it "should pass if importer_id is linked company" do
      put :update, 'id'=>@product.id, 'product'=>{'prod_uid'=>'abc123455_pccreate','prod_imp_id'=>@linked_importer.id}
      p = Product.find @product.id
      p.unique_identifier.should == "abc123455_pccreate"
      p.importer.should == @linked_importer
    end
    it "should pass if importer_id is current company" do
      put :update, 'id'=>@product.id, 'product'=>{'prod_uid'=>'abc123455_pccreate','prod_imp_id'=>@user.company.id}
      p = Product.find @product.id
      p.unique_identifier.should == "abc123455_pccreate"
      p.importer.should == @user.company
    end
    it "should clear custom value at classification level" do
      cntry = Factory(:country)
      cls = Factory(:classification,product:@product,country:cntry)
      cd = Factory(:custom_definition,module_type:'Classification',data_type:'string')
      cls.update_custom_value!(cd,'abc')
      put :update, id:@product.id, 'product'=>{'prod_uid'=>'1234','classifications_attributes'=>{'0'=>{'id'=>cls.id.to_s, 'class_cntry_id' => cntry.id.to_s, cd.model_field_uid.to_s => ''}}}
      p = Product.find @product.id
      expect(p.classifications.first.get_custom_value(cd).value).to be_blank
    end
  end

  describe :bulk_update do
    it "should bulk update inline for less than 10 products" do
      OpenChain::BulkUpdateClassification.should_receive(:go) do |params, user, opts| 
        params['product']['classifications_attributes'].should == {"us" => "1"}
        user.id.should == @user.id
        opts[:no_user_message].should be_true

        params[:product][:uniqe_identifier].should be_nil
        params[:product][:id].should be_nil
        params[:product][:vendor_id].should be_nil
        params[:product][:field2].should be_nil
        params[:utf8].should be_nil
        params[:pk]["0"].should == "0"
        params[:pk]["9"].should == "9"

        {:message => "Test", :errors => ["1", "2"]}
      end
      # Several fields are not allowed to be bulk updated (as well as blank values)
      p = {:product => {:field => "value", :unique_identifier => "v", :id=>"id", :vendor_id=>"id", :field2 => '', :classifications_attributes=>{"us"=>"1"}}, :utf8 => 'v'}
      pks = {}
      (0..9).each do |i|
        pks[i.to_s] = i.to_s
      end
      p[:pk] = pks
      
      post :bulk_update, p
      expect(response).to redirect_to controller.advanced_search(CoreModule::PRODUCT, false, true)
      flash[:notices].first.should == "Test"
      flash[:errors][0].should == "1"
      flash[:errors][1].should == "2"
    end

    it "should delay bulk updates with over 10 keys" do
      p = {:product => {:field => "value"}}
      pks = {}
      (0..10).each do |i|
        pks[i.to_s] = i.to_s
      end
      p[:pk] = pks
    
      bulk = double("OpenChain::BulkUpdateClassification")
      OpenChain::BulkUpdateClassification.should_receive(:delay).and_return(bulk)
      bulk.should_receive(:go_serializable) do |params, id| 
        id.should == @user.id
        params = JSON.parse params
        params['pk'].length.should == 11
        params['product']['field'].should == "value"
      end

      post :bulk_update, p
      expect(response).to redirect_to controller.advanced_search(CoreModule::PRODUCT, false, true)
      flash[:notices].first.should == "These products will be updated in the background.  You will receive a system message when they're ready." 
    end

    it "should delay bulk updates for search runs" do
      p = {:product => {:field => "value"}, :sr_id => 1, :pk => {"0" => "0"}}
      
      bulk = double("OpenChain::BulkUpdateClassification")
      OpenChain::BulkUpdateClassification.should_receive(:delay).and_return(bulk)
      bulk.should_receive(:go_serializable) do |params, id| 
        id.should == @user.id
        params = JSON.parse params
        params['sr_id'].should == "1"
        params['product']['field'].should == "value"
      end

      post :bulk_update, p
      expect(response).to redirect_to controller.advanced_search(CoreModule::PRODUCT, false, true)
      flash[:notices].first.should == "These products will be updated in the background.  You will receive a system message when they're ready." 
    end
  end

  describe "bulk_update_classifications" do
    it "should run delayed for search runs" do
      p = {:sr_id=>1}

      b = double
      OpenChain::BulkUpdateClassification.should_receive(:delay).and_return(b)
      b.should_receive(:quick_classify) do |json, id|
        id.should == @user
        params = ActiveSupport::JSON.decode json
        params["sr_id"].should == "1"
      end

      post :bulk_update_classifications, p
      response.should redirect_to Product 
      flash[:notices].first.should == "These products will be updated in the background.  You will receive a system message when they're ready." 
    end

    it "should run delayed for more than 10 products" do
      pks = {}
      (0..10).each do |i|
        pks[i.to_s] = i.to_s
      end
      p = {:pk => pks}
      
      b = double
      OpenChain::BulkUpdateClassification.should_receive(:delay).and_return(b)
      b.should_receive(:quick_classify) do |json, id|
        id.should == @user
        params = ActiveSupport::JSON.decode json
        params["pk"].length.should == 11
      end

      post :bulk_update_classifications, p
      response.should redirect_to Product 
      flash[:notices].first.should == "These products will be updated in the background.  You will receive a system message when they're ready." 
    end

    it "should not run delayed for 10 products" do
      pks = {}
      (0..9).each do |i|
        pks[i.to_s] = i.to_s
      end
      p = {:pk => pks}
      b = BulkProcessLog.create!
      OpenChain::BulkUpdateClassification.should_receive(:quick_classify) do |params, u, options|
        u.should == @user
        params[:pk].length.should == 10
        options[:no_user_message].should be_true
        b
      end

      post :bulk_update_classifications, p
      response.should redirect_to products_path
    end

    it "should allow user to bulk update classifications" do
      delay = double
      p = {"k1"=>"v1", "k2"=>"v2", :sr_id=>"1"}
      OpenChain::BulkUpdateClassification.should_receive(:delay).and_return delay
      delay.should_receive(:quick_classify) do |args, id| 
        json = JSON.parse(args)
        json["k1"].should == "v1"
        json["k2"].should == "v2"
        id.should == @user
      end

      request.env["HTTP_REFERER"] = "http://www.test.com?force_search=true&key=val" 
      post :bulk_update_classifications, p
      flash[:notices].should == ["These products will be updated in the background.  You will receive a system message when they're ready."]
      response.should redirect_to Product
    end
    
    it "should redirect to products_path with no referer" do
      delay = double
      p = {:sr_id => "1"}
      OpenChain::BulkUpdateClassification.should_receive(:delay).and_return delay
      delay.should_receive(:quick_classify)
      request.env["HTTP_REFERER"] = nil
      post :bulk_update_classifications, p
      response.should redirect_to(products_path)
    end

    it "should redirect to 'back_to' parameter if set" do
      request.env["HTTP_REFERER"] = "http://www.test.com?force_search=true&key=x" 
      delay = double
      OpenChain::BulkUpdateClassification.should_receive(:delay).and_return delay
      delay.should_receive(:quick_classify)
      post :bulk_update_classifications, {'back_to'=>'/somewhere?force_search=true&key=val', :sr_id=>"1"}
      response.should redirect_to("http://test.host/somewhere?key=val")
    end
  end
end
