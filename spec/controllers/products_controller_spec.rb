require 'spec_helper'

describe ProductsController do
  before :each do
    activate_authlogic
    @user = Factory(:importer_user,:product_edit=>true,:product_view=>true,:classification_edit=>true)
    @other_importer = Factory(:company,:importer=>true)
    @linked_importer = Factory(:company,:importer=>true)
    @user.company.linked_companies << @linked_importer
    UserSession.create! @user
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
      post :create, 'product'=>{'unique_identifier'=>'abc123455_pccreate','importer_id'=>@other_importer.id}
      flash[:errors].first.should == "You do not have permission to set importer to company #{@other_importer.id}"
    end
    it "should pass if importer_id is current company" do
      post :create, 'product'=>{'unique_identifier'=>'abc123455_pccreate','importer_id'=>@user.company.id}
      p = Product.first
      p.unique_identifier.should == "abc123455_pccreate"
      p.importer.should == @user.company
    end
    it "should pass if importer_id is linked company" do
      post :create, 'product'=>{'unique_identifier'=>'abc123455_pccreate','importer_id'=>@linked_importer.id}
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
      put :update, 'id'=>@product.id, 'product'=>{'unique_identifier'=>'abc123455_pccreate','importer_id'=>@other_importer.id}
      flash[:errors].first.should == "You do not have permission to set importer to company #{@other_importer.id}"
    end
    it "should pass if importer_id is linked company" do
      put :update, 'id'=>@product.id, 'product'=>{'unique_identifier'=>'abc123455_pccreate','importer_id'=>@linked_importer.id}
      p = Product.find @product.id
      p.unique_identifier.should == "abc123455_pccreate"
      p.importer.should == @linked_importer
    end
    it "should pass if importer_id is current company" do
      put :update, 'id'=>@product.id, 'product'=>{'unique_identifier'=>'abc123455_pccreate','importer_id'=>@user.company.id}
      p = Product.find @product.id
      p.unique_identifier.should == "abc123455_pccreate"
      p.importer.should == @user.company
    end
  end

  describe :bulk_update do
    it "should bulk update inline for less than 10 products" do
      # Several fields are not allowed to be bulk updated (as well as blank values)
      p = {:product => {:field => "value", :unique_identifier => "v", :id=>"id", :vendor_id=>"id", :field2 => ''}, :utf8 => 'v'}
      pks = {}
      (0..9).each do |i|
        pks[i.to_s] = i.to_s
      end
      p[:pk] = pks

      Product.should_receive(:batch_bulk_update) do |u, params, options| 
        u.id.should == @user.id
        params[:product][:uniqe_identifier].should be_nil
        params[:product][:id].should be_nil
        params[:product][:vendor_id].should be_nil
        params[:product][:field2].should be_nil
        params[:utf8].should be_nil
        params[:pk]["0"].should == "0"
        params[:pk]["9"].should == "9"
        options[:no_email].should be_true
        {:message => "Test"}
      end
      
      post :bulk_update, p
      response.should redirect_to products_path
      flash[:notices].first.should == "Test"
    end

    it "should show errors for inline bulk updates" do
      p = {:product_cf => {:field => "v", :field2 => ""}, :pk => {"0" => '0'}, :product => {:id => ""}}
      
      Product.should_receive(:batch_bulk_update) do |u, params, options| 
        params[:product_cf][:field2].should be_nil
        options[:no_email].should be_true
  
        {:message => "Test", :errors => ["1", "2"]}
      end

      post :bulk_update, p
      response.should redirect_to products_path
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
    
      prod = double
      Product.should_receive(:delay).and_return(prod)
      prod.should_receive(:batch_bulk_update) do |u, params| 
        u.id.should == @user.id
        params[:pk].length.should == 11
        params[:product][:field].should == "value"
      end

      post :bulk_update, p
      response.should redirect_to products_path
      flash[:notices].first.should == "These products will be updated in the background.  You will receive a system message when they're ready." 
    end

    it "should delay bulk updates for search runs" do
      p = {:product => {:field => "value"}, :sr_id => 1, :pk => {"0" => "0"}}
      prod = double
      Product.should_receive(:delay).and_return(prod)
      prod.should_receive(:batch_bulk_update) do |u, params| 
        u.id.should == @user.id
        params[:sr_id].should == "1"
        params[:product][:field].should == "value"
      end

      post :bulk_update, p
      response.should redirect_to products_path
      flash[:notices].first.should == "These products will be updated in the background.  You will receive a system message when they're ready." 
    end
  end

  describe "bulk_update_classifications" do
    it "should run delayed for search runs" do
      p = {:sr_id=>1}

      b = double
      OpenChain::BulkUpdateClassification.should_receive(:delay).and_return(b)
      b.should_receive(:go_serializable) do |json, id|
        id.should == @user.id
        params = ActiveSupport::JSON.decode json
        params["sr_id"].should == "1"
      end

      post :bulk_update_classifications, p
      response.should redirect_to request.referer
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
      b.should_receive(:go_serializable) do |json, id|
        id.should == @user.id
        params = ActiveSupport::JSON.decode json
        params["pk"].length.should == 11
      end

      post :bulk_update_classifications, p
      response.should redirect_to request.referer
      flash[:notices].first.should == "These products will be updated in the background.  You will receive a system message when they're ready." 
    end

    it "should not run delayed for 10 products" do
      pks = {}
      (0..9).each do |i|
        pks[i.to_s] = i.to_s
      end
      p = {:pk => pks}
      
      OpenChain::BulkUpdateClassification.should_receive(:go) do |params, u, options|
        u.id.should == @user.id
        params[:pk].length.should == 10
        options[:no_user_message].should be_true
        {:message => "Test", :errors =>["A", "B"]}
      end

      post :bulk_update_classifications, p
      response.should redirect_to request.referer
      flash[:notices].first.should == "Test"
      flash[:errors].should == ["A", "B"]
    end

    it "should allow user to bulk update classifications" do
      delay = double
      p = {"k1"=>"v1", "k2"=>"v2", :sr_id=>"1"}
      OpenChain::BulkUpdateClassification.should_receive(:delay).and_return delay
      delay.should_receive(:go_serializable) do |args, id| 
        json = JSON.parse(args)
        json["k1"].should == "v1"
        json["k2"].should == "v2"
        id.should == @user.id
      end

      request.env["HTTP_REFERER"] = "http://www.test.com?force_search=true&key=val" 
      post :bulk_update_classifications, p
      flash[:notices].should == ["These products will be updated in the background.  You will receive a system message when they're ready."]
      response.should redirect_to("http://www.test.com?key=val")
    end
    
    it "should redirect to products_path with no referer" do
      delay = double
      p = {:sr_id => "1"}
      OpenChain::BulkUpdateClassification.should_receive(:delay).and_return delay
      delay.should_receive(:go_serializable)
      request.env["HTTP_REFERER"] = nil
      post :bulk_update_classifications, p
      response.should redirect_to(products_path)
    end

    it "should redirect to 'back_to' parameter if set" do
      request.env["HTTP_REFERER"] = "http://www.test.com?force_search=true&key=x" 
      delay = double
      OpenChain::BulkUpdateClassification.should_receive(:delay).and_return delay
      delay.should_receive(:go_serializable)
      post :bulk_update_classifications, {'back_to'=>'/somewhere?force_search=true&key=val', :sr_id=>"1"}
      response.should redirect_to("http://test.host/somewhere?key=val")
    end
  end
end
