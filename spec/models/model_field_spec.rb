require 'spec_helper'

describe ModelField do
  describe "Product Custom Defintion On Other Module" do
    before :each do
      @cd = Factory(:custom_definition,module_type:'Product',data_type:'string')
      @p = Factory(:product)
      @p.update_custom_value!(@cd,'ABC')
      order_line = Factory(:order_line) #make to ensure that order_lines.id != products.id
      @order_line = Factory(:order_line, product:@p, order: order_line.order)
      @mf = ModelField.create_and_insert_product_custom_field @cd, CoreModule::ORDER_LINE, 1
      MasterSetup.get.update_attributes(order_enabled:true)
    end
    it "should query properly" do
      ss = SearchSetup.new(module_type:'Order')
      ss.search_columns.build(model_field_uid:@mf.uid,rank:1)
      ss.search_criterions.build(model_field_uid:@mf.uid,operator:'sw',value:'A')
      u = Factory(:master_user,order_view:true)
      h = SearchQuery.new(ss,u).execute
      expect(h.size).to eq(1)
      expect(h.first[:row_key]).to eq @order_line.order.id
      expect(h.first[:result].first).to eq 'ABC'
    end
    it "should be read only" do
      expect(@mf.process_import(@order_line,'DEF',Factory(:user))).to eq "Value ignored. #{@mf.label} is read only."
      expect(@mf.read_only?).to be_truthy
    end
    it "should export properly" do
      u = Factory(:master_user,order_view:true)
      expect(@mf.process_export(@order_line,u)).to eq 'ABC'
    end
  end
  describe "process_query_result" do
    before :each do
      @u = User.new
    end
    it "should pass vlue through for default object" do
      expect(ModelField.new(10000,:test,CoreModule::PRODUCT,:name).process_query_result("x",@u)).to eq("x")
    end
    it "should override with given lambda" do
      expect(ModelField.new(10000,:test,CoreModule::PRODUCT,:name,:process_query_result_lambda=>lambda {|v| v.upcase}).process_query_result("x",@u)).to eq("X")
    end
    it "should write HIDDEN if user cannot view column" do
      expect(ModelField.new(10000,:test,CoreModule::PRODUCT,:name,:can_view_lambda=>lambda {|u| false}).process_query_result("x",@u)).to be_nil
    end
    it "utilizes the user's timezone to translate date time values" do
      @u.time_zone = "Hawaii"
      time = Time.now.in_time_zone 'GMT'
      result = ModelField.new(10000,:test,CoreModule::PRODUCT,:name,:process_query_result_lambda=>lambda {|v| time}).process_query_result("x",@u)
      #Without the to_s the times compare by clockticks since epoch, which isn't what we want here
      expect(result.to_s).to eq time.in_time_zone('Hawaii').to_s
    end
    it "defaults timezone translation to Eastern" do
      @u.time_zone = nil
      time = Time.now.in_time_zone 'GMT'
      result = ModelField.new(10000,:test,CoreModule::PRODUCT,:name,:process_query_result_lambda=>lambda {|v| time}).process_query_result("x",@u)
      #Without the to_s the times compare by clockticks since epoch, which isn't what we want here
      expect(result.to_s).to eq time.in_time_zone('Eastern Time (US & Canada)').to_s
    end
  end
  context "read_only" do
    before :each do
    end
    after :each do
      FieldLabel.set_default_value :x, nil
    end
    it "should default to not being read only" do
      mf = ModelField.new(1,:x,CoreModule::PRODUCT,:name,{:data_type=>:string})
      expect(mf).not_to be_read_only
      p = Product.new
      mf.process_import p, "n", User.new
      expect(p.name).to eq 'n'
    end
    it "should not write if read only" do
      FieldLabel.set_label :x, "PLBL"
      mf = ModelField.new(1,:x,CoreModule::PRODUCT,:name,{:data_type=>:string,:read_only=>true})
      expect(mf).to be_read_only
      p = Product.new(:name=>'x')
      r = mf.process_import p, 'n', User.new
      expect(p.name).to eq 'x'
      expect(r).to eq "Value ignored. PLBL is read only."
    end
    it "should set read_only for custom_defintion that is read only" do
      cd = Factory :custom_definition
      ModelField.reload
      fvr = FieldValidatorRule.new
      fvr.read_only = true
      fvr.model_field_uid = "*cf_#{cd.id}"
      fvr.save!
      ModelField.reload
      expect(ModelField.find_by_uid("*cf_#{cd.id}")).to be_read_only
    end
    it "should not set read_only for custom_definition that isn't read only" do
      cd = Factory(:custom_definition)
      ModelField.reload
      expect(ModelField.find_by_uid("*cf_#{cd.id}")).not_to be_read_only
    end

    it "should set read_only for normal read_only field" do
      mf = ModelField.find_by_uid :prod_uid
      expect(mf).not_to be_read_only
      FieldValidatorRule.create!(model_field_uid: :prod_uid, read_only: true)
      ModelField.reload
      mf = ModelField.find_by_uid :prod_uid
      expect(mf).to be_read_only
    end

  end
  describe "can_view?" do
    it "should default to true" do
      expect(ModelField.new(1,:x,CoreModule::SHIPMENT,:z).can_view?(Factory(:user))).to be_truthy
    end
    it "should be false when lambda returns false" do
      expect(ModelField.new(1,:x,CoreModule::SHIPMENT,:z,{:can_view_lambda=>lambda {|user| false}}).can_view?(Factory(:user))).to be_falsey
    end

    it "allows if view lambda is not set" do
      #edit lambda below is ignored
      expect(ModelField.new(1,:x,CoreModule::SHIPMENT,:z,{:can_edit_lambda=>lambda {|user| false}}).can_view?(Factory(:user))).to be_truthy
    end

    it "allows viewing when user is in FieldValidatorRule view group" do
      FieldValidatorRule.create! module_type: "Entry", model_field_uid: 'uid', can_view_groups: "GROUP1\nGROUP"
      user = Factory(:user)
      user.groups << Factory(:group, system_code: "GROUP")
      expect(ModelField.new(1, :uid, CoreModule::ENTRY, "UID").can_view? user).to be_truthy
    end

    it "allows viewing when user is in FieldValidatorRule edit group" do
      FieldValidatorRule.create! module_type: "Entry", model_field_uid: 'uid', can_edit_groups: "GROUP1\nGROUP"
      user = Factory(:user)
      user.groups << Factory(:group, system_code: "GROUP")
      expect(ModelField.new(1, :uid, CoreModule::ENTRY, "UID").can_view? user).to be_truthy
    end

    it "prevents viewing if user is in view group but lambda blocks access" do
      FieldValidatorRule.create! module_type: "Entry", model_field_uid: 'uid', can_view_groups: "GROUP1\nGROUP"
      user = Factory(:user)
      user.groups << Factory(:group, system_code: "GROUP")
      expect(ModelField.new(1,:x,CoreModule::SHIPMENT,:z,{:can_view_lambda=>lambda {|user| false}}).can_view?(user)).to be_falsey
    end

    it "prevents viewing when user is not in a group allowed to view the field" do
      FieldValidatorRule.create! module_type: "Entry", model_field_uid: 'uid', can_view_groups: "GROUP"
      user = Factory(:user)
      expect(ModelField.new(1, :uid, CoreModule::ENTRY, "UID").can_view? user).to be_falsey
    end

    it "allows viewing when allow_everyone_to_view exists on the FieldValidatorRule" do
      FieldValidatorRule.create! module_type: "Entry", model_field_uid: 'uid', can_edit_groups: "GROUP", allow_everyone_to_view: true
      user = Factory(:user)
      expect(ModelField.new(1, :uid, CoreModule::ENTRY, "UID").can_view? user).to eq true
    end

    it "disallows viewing when an edit group is set for the FieldValidatorRule and user is not in that group" do
      # I'm not sure if this is a bug or a feature...I would think that since there's a view / edit groups that 
      # if the view group was blank, anyone can view it....however, due to the sheer number of fields that lumber 
      # has that have this exact setup and are likely relying on this behavior, I'm not going to change this.
      # This is the reason that FieldValidatorRule#allow_everyone_to_view exists.
      FieldValidatorRule.create! module_type: "Entry", model_field_uid: 'uid', can_edit_groups: "GROUP"
      user = Factory(:user)
      expect(ModelField.new(1, :uid, CoreModule::ENTRY, "UID").can_view? user).to eq false
    end
  end

  describe "can_mass_edit?" do
    it 'disallows mass_edit by default' do
      expect(ModelField.new(1, :x, CoreModule::SHIPMENT, :z).can_mass_edit?(Factory(:user))).to be_falsey
    end

    it 'allows mass_edit if field is mass_edit, and no groups are provided' do
      expect(ModelField.new(1, :x, CoreModule::SHIPMENT, :z, mass_edit: true).can_mass_edit?(Factory(:user))).to be_truthy
    end

    it 'disallows mass_edit if field is not user accessible' do
      expect(ModelField.new(1, :x, CoreModule::SHIPMENT, :z, user_accessible: false, mass_edit: true).can_mass_edit?(Factory(:user))).to be_falsey
    end

    it 'disallows mass_edit if fields cannot be edited by user' do
      expect(ModelField.new(1, :x, CoreModule::SHIPMENT, :z, user_accessible: true, mass_edit: true, read_only: true).can_mass_edit?(Factory(:user))).to be_falsey
    end

    it 'disallows mass_edit if user is not in mass_edit group, if group is provided' do
      FieldValidatorRule.create! module_type: "Order", model_field_uid: 'uid', can_mass_edit_groups: "Group"
      user = Factory(:user)
      expect(ModelField.new(1, :uid, CoreModule::ORDER, "UID", mass_edit: true).can_mass_edit?(user)).to be_falsey
    end

    it 'allows mass_edit if user is in the mass_edit group, if group is provided' do
      FieldValidatorRule.create! module_type: "Order", model_field_uid: "uid", can_mass_edit_groups: "GROUP1\nGROUP"
      user = Factory(:user)
      user.groups << Factory(:group, system_code: "GROUP")
      expect(ModelField.new(1, :uid, CoreModule::ORDER, "UID", mass_edit: true).can_mass_edit?(user)).to be_truthy
    end
  end

  describe "can_edit?" do
    it "allows edit by default" do
      expect(ModelField.new(1,:x,CoreModule::SHIPMENT,:z).can_edit?(Factory(:user))).to be_truthy
    end

    it "disallows edit if can_edit_lambda returns false" do
      expect(ModelField.new(1,:x,CoreModule::SHIPMENT,:z, can_edit_lambda: lambda {|u| false}).can_edit?(Factory(:user))).to be_falsey
    end

    it "disallows edit if model field is read-only" do
      expect(ModelField.new(1,:x,CoreModule::SHIPMENT,:z, read_only: true).can_edit?(Factory(:user))).to be_falsey
    end

    it "uses can_view_lambda if no edit lambda exists" do
      lambda_called = true
      expect(ModelField.new(1,:x,CoreModule::SHIPMENT,:z, can_view_lambda: lambda {|u| lambda_called=true; false}).can_edit?(Factory(:user))).to be_falsey
      expect(lambda_called).to be_truthy
    end

    it "it allows edit if user is in edit group" do
      FieldValidatorRule.create! module_type: "Entry", model_field_uid: 'uid', can_edit_groups: "GROUP1\nGROUP"
      user = Factory(:user)
      user.groups << Factory(:group, system_code: "GROUP")
      expect(ModelField.new(1, :uid, CoreModule::ENTRY, "UID").can_edit? user).to be_truthy
    end

    it "disallows edit if user is not in edit group" do
      FieldValidatorRule.create! module_type: "Entry", model_field_uid: 'uid', can_edit_groups: "GROUP"
      user = Factory(:user)
      expect(ModelField.new(1, :uid, CoreModule::ENTRY, "UID").can_edit? user).to be_falsey
    end

    it "allows edit if user is in view group when no edit groups exist" do
      FieldValidatorRule.create! module_type: "Entry", model_field_uid: 'uid', can_view_groups: "GROUP"
      user = Factory(:user)
      user.groups << Factory(:group, system_code: "GROUP")
      expect(ModelField.new(1, :uid, CoreModule::ENTRY, "UID").can_edit? user).to be_truthy
    end

    it "disallows edit if user is in view group when edit groups exist" do
      FieldValidatorRule.create! module_type: "Entry", model_field_uid: 'uid', can_view_groups: "GROUP", can_edit_groups: "GROUP2"
      user = Factory(:user)
      user.groups << Factory(:group, system_code: "GROUP")
      expect(ModelField.new(1, :uid, CoreModule::ENTRY, "UID").can_edit? user).to be_falsey
    end
  end

  describe "process_export" do
    it "returns return HIDDEN for process_export if can_view? is false" do
      expect(ModelField.new(1,:x,CoreModule::SHIPMENT,:z,{:export_lambda=>lambda {|obj| "a"},:can_view_lambda=>lambda {|u| false}}).process_export("x",User.new)).to be_nil
    end
    it "should return appropriate value for process_export if can_view? is true" do
      expect(ModelField.new(1,:x,CoreModule::SHIPMENT,:z,{:export_lambda=>lambda {|obj| "a"},:can_view_lambda=>lambda {|u| true}}).process_export("x",User.new)).to eq "a"
    end
    it "should skip check if always_view is true" do
      expect(ModelField.new(1,:x,CoreModule::SHIPMENT,:z,{:export_lambda=>lambda {|obj| "a"},:can_view_lambda=>lambda {|u| false}}).process_export("x",User.new,true)).to eq "a"
    end
    it "returns nil if field is disabled" do
      expect(ModelField.new(1,:x,CoreModule::SHIPMENT,nil, disabled: true).process_export("x", User.new)).to be_nil
    end
    it "retrieves custom values" do
      cd = CustomDefinition.create! data_type: :string, module_type: "Shipment", label: "TEST"
      mf = ModelField.new(1, :x, CoreModule::SHIPMENT, nil, custom_id: cd.id, can_view_lambda: lambda {|u| true})
      ship = Factory(:shipment)
      ship.update_custom_value! cd, "TESTING!!!"
      expect(mf.custom?).to be_truthy
      expect(mf.process_export ship, User.new).to eq "TESTING!!!"
    end
    it "retrieves standard field values" do
      mf = ModelField.new(1, :shp_ref, CoreModule::SHIPMENT, :reference)
      # Using a non-shipment object because I want to ensure that this method is literally
      # just doing the equivalent of and obj.field_name method call (rather than ActiveRecord attribute accessing, etc.)
      c = Class.new do
        def reference
          "TEST!!!"
        end
      end
      expect(mf.process_export c.new, User.new).to eq "TEST!!!"
    end
    it "uses export lambda when defined" do
      called = nil
      mf = ModelField.new(1, :shp_ref, CoreModule::SHIPMENT, :reference, export_lambda: lambda {|obj| called = obj; "EXPORT"})
      expect(mf.process_export "TEST", User.new).to eq "EXPORT"
      expect(called).to eq "TEST"
    end
  end

  describe "process_import" do
    it "updates an object's value" do
      mf = ModelField.new(1, :shp_ref, CoreModule::SHIPMENT, :reference, default_label: "MY LABEL")
      c = Class.new do
        attr_reader :reference
        def reference= ref
          @reference = ref
        end
      end
      c = c.new
      result = mf.process_import c, "TESTING", User.new
      expect(result).to eq "MY LABEL set to TESTING"
      expect(result.error?).to be_falsey
      expect(c.reference).to eq "TESTING"
    end

    it "updates a custom field" do
      cd = CustomDefinition.create! data_type: :string, module_type: "Shipment", label: "TEST"
      mf = ModelField.new(1, :x, CoreModule::SHIPMENT, nil, custom_id: cd.id, can_view_lambda: lambda {|u| true})
      ship = Factory(:shipment)
      ship.update_custom_value! cd, "BEFORE TEST"

      result = mf.process_import ship, "TESTING", User.new
      expect(result).to eq "TEST set to TESTING"
      expect(result.error?).to be_falsey
      expect(ship.get_custom_value(cd).value).to eq "TESTING"
    end

    it "updates a date field w/ hyphens" do
      mf = ModelField.new(1, :shp_ref, CoreModule::SHIPMENT, :reference, default_label: "MY LABEL", data_type: :date)
      c = Class.new do
        attr_reader :reference
        def reference= ref
          @reference = ref
        end
      end
      c = c.new
      # The following looks like a bug to me because we're parsing XX-XX-XXXX as Day-Month-Year
      # versus the US standard Month-Day-Year...it's possible that we meant hyphens to parse in the non-US
      # standard format, but I'm dubious.

      # I'm leaving in place since the code is long lived and copied into custom_value.rb as well.
      result = mf.process_import c, "02-01-2014", User.new
      expect(result).to eq "MY LABEL set to #{Date.new(2014, 1, 2)}"
      expect(result.error?).to be_falsey
      expect(c.reference).to eq Date.new(2014, 1, 2)
    end

    it "updates a date field w/ slashes" do
      mf = ModelField.new(1, :shp_ref, CoreModule::SHIPMENT, :reference, default_label: "MY LABEL", data_type: :date)
      c = Class.new do
        attr_reader :reference
        def reference= ref
          @reference = ref
        end
      end
      c = c.new
      result = mf.process_import c, "02/01/2014", User.new
      expect(result).to eq "MY LABEL set to #{Date.new(2014, 2, 1)}"
      expect(result.error?).to be_falsey
      expect(c.reference).to eq Date.new(2014, 2, 1)
    end

    it "sets the value when a CustomValue is passed" do
      cd = CustomDefinition.create! data_type: :string, module_type: "Shipment", label: "TEST"
      mf = ModelField.new(1, :shp_ref, CoreModule::SHIPMENT, :reference, default_label: "MY LABEL", data_type: :string)
      cv = CustomValue.new custom_definition: cd

      result = mf.process_import cv, "TEST123", User.new
      expect(result).to eq "MY LABEL set to TEST123"
      expect(result.error?).to be_falsey
      expect(cv.value).to eq "TEST123"
    end

    it "ignores read_only? fields" do
      mf = ModelField.new(1, :shp_ref, CoreModule::SHIPMENT, :reference, default_label: "MY LABEL", read_only: true)
      result = mf.process_import "Object", "MY Value", User.new
      expect(result).to eq "Value ignored. MY LABEL is read only."
      expect(result.error?).to be_falsey
    end

    it "uses import_lambda if given" do
      my_obj = nil
      my_data = nil
      mf = ModelField.new(1, :shp_ref, CoreModule::SHIPMENT, :reference, default_label: "MY LABEL", import_lambda: lambda {|obj, data| my_obj=obj; my_data=data; "IMPORTED!"})
      result = mf.process_import "OBJ", "DATA", User.new
      expect(result).to eq "IMPORTED!"
      expect(result.error?).to be_falsey
      expect(my_obj).to eq "OBJ"
      expect(my_data).to eq "DATA"
    end

    it "does not use import_lambda if field is read_only" do
      mf = ModelField.new(1, :shp_ref, CoreModule::SHIPMENT, :reference, default_label: "MY LABEL", read_only: true, import_lambda: lambda {|obj, data| raise "ERROR!!!"})
      result = mf.process_import "Object", "MY Value", User.new
      expect(result).to eq "Value ignored. MY LABEL is read only."
      expect(result.error?).to be_falsey
    end

    it "does process import if read_only and bypass_read_only==true" do
      s = Shipment.new
      mf = ModelField.new(1, :shp_ref, CoreModule::SHIPMENT, :reference, default_label: "MY LABEL", read_only: true)
      allow(mf).to receive(:can_edit?).and_return true
      mf.process_import s, "MY Value", User.new, bypass_read_only: true
      expect(s.reference).to eq "MY Value"
    end

    it "does not allow import for user that cannot edit the field" do
      mf = ModelField.new(1, :shp_ref, CoreModule::SHIPMENT, :reference, default_label: "MY LABEL", import_lambda: lambda {|obj, data| raise "ERROR!!!"})
      u = User.new
      expect(mf).to receive(:can_edit?).with(u).and_return false
      result = mf.process_import "Object", "MY Value", u
      expect(result).to eq "You do not have permission to edit #{mf.label}."
      expect(result.error?).to be_truthy
    end

    it "allows caller to forcefully allow import even if user might not be able to import" do
      mf = ModelField.new(1, :shp_ref, CoreModule::SHIPMENT, :reference, default_label: "MY LABEL")
      c = Class.new do
        attr_reader :reference
        def reference= ref
          @reference = ref
        end
      end
      c = c.new
      allow(mf).to receive(:can_edit?).and_return false
      result = mf.process_import c, "TESTING", User.new, bypass_user_check: true
      expect(result).to eq "MY LABEL set to TESTING"
      expect(result.error?).to be_falsey
      expect(c.reference).to eq "TESTING"
    end
  end

  it "should get uid for region" do
    r = Factory(:region)
    expect(ModelField.uid_for_region(r,"x")).to eq "*r_#{r.id}_x"
  end

  context "special cases" do
    describe 'ports' do
      let (:port) { Factory(:port,name:'MyName') }
      let (:user) { Factory(:master_user,shipment_view:true) }
      let (:search_setup) { 
        ss = SearchSetup.new(module_type:'Shipment',user_id:user.id) 
        ss.search_columns.build(model_field_uid: uid, rank: 1)
        ss
      }

      let (:model_field) { ModelField.find_by_uid(uid) }
      let (:shipment) { Shipment.new reference: "REF", destination_port: port }

      context "using port name field" do
        let (:uid) { 'shp_dest_port_name' }
        let! (:search_criterions) { search_setup.search_criterions.build(model_field_uid:uid, operator:'eq', value:port.name)}

        it "should process_export" do
          expect(model_field.process_export(shipment,user,true)).to eq port.name
        end

        it "should not process_import (readonly)" do
          v = model_field.process_import shipment, port.name, user
          expect(v).to eq "Value ignored. Discharge Port Name is read only."
        end

        it "should find" do
          shipment.save!
          expect(search_setup.result_keys).to eq [shipment.id]
        end
      end

      context "using port id field" do
        let (:uid) { 'shp_dest_port_id' }
        let! (:search_criterions) { search_setup.search_criterions.build(model_field_uid:uid, operator:'eq', value:port.id)}
        
        it "should process_export" do
          expect(model_field.process_export(shipment,user,true)).to eq port.id
        end

        it "should process_import" do
          model_field.process_import shipment, port.id, user
          expect(shipment.destination_port).to eq port
        end

        it "should find" do
          shipment.save!
          expect(search_setup.result_keys).to eq [shipment.id]
        end
      end
    end

    context "prod_max_component_count" do
      before :each do
        @ss = SearchSetup.new(module_type:'Product',user_id:Factory(:master_user,product_view:true).id)
        @ss.search_columns(model_field_uid:'prod_uid',rank:1)
        @sc = @ss.search_criterions.build(model_field_uid: 'prod_max_component_count', operator:'eq',value:'0')
        @mf = ModelField.find_by_uid(:prod_max_component_count)
      end
      it "should return number for maximum components" do
        #first record for country 1
        tr = Factory(:tariff_record)
        p = tr.product
        #second record for country 1
        tr2 = Factory(:tariff_record,classification:tr.classification,line_number:2)
        #first record for country 2
        tr3 = Factory(:tariff_record,classification:Factory(:classification,product:p))
        expect(@mf.process_export(p,nil,true)).to eq 2
        @sc.value = '2'
        expect(@ss.result_keys.to_a).to eq [p.id]
      end
      it "should return 0 when no classifications" do
        p = Factory(:product)
        expect(@mf.process_export(p,nil,true)).to eq 0
        expect(@ss.result_keys.to_a).to eq [p.id]
      end
      it "should return 0 when no components" do
        c = Factory(:classification)
        p = c.product
        expect(@mf.process_export(p,nil,true)).to eq 0
        expect(@ss.result_keys.to_a).to eq [p.id]
      end
    end
    context "comments" do
      it "should return comment count" do
        s = Factory(:shipment)
        u = Factory(:user)
        s.comments.create!(user_id:u.id,subject:"x")
        expect(ModelField.find_by_uid(:shp_comment_count).process_export(s,u,true)).to eq 1
      end
    end
    context "first hts by country" do
      before :each do
        @c = Factory(:country,:iso_code=>'ZY',:import_location=>true)
        ModelField.reload true
      end
      it "should create fields for each import country" do
        c2 = Factory(:country,:iso_code=>'ZZ',:import_location=>true)
        c3 = Factory(:country,:iso_code=>'NO',:import_location=>false)
        ModelField.reload true
        (1..3).each do |i|
          c_mf = ModelField.find_by_uid "*fhts_#{i}_#{@c.id}"
          expect(c_mf.label).to eq "First HTS #{i} (ZY)"
          c2_mf = ModelField.find_by_uid "*fhts_#{i}_#{c2.id}"
          expect(c2_mf.label).to eq "First HTS #{i} (ZZ)"
          expect(ModelField.model_field_loaded?("*fhts_#{i}_#{c3.id}")).to be_falsey #don't create because not an import location
        end
      end
      it "should allow import" do
        ModelField.reload true
        p = Factory(:product)
        (1..3).each do |i|
          Factory(:official_tariff,:country=>@c,:hts_code=>"123456789#{i}")
          mf = ModelField.find_by_uid "*fhts_#{i}_#{@c.id}"
          r = mf.process_import(p, "123456789#{i}", User.new)
          expect(r).to eq "ZY HTS #{i} set to 1234.56.789#{i}"
        end
        p.save!
        expect(p.classifications.size).to eq(1)
        cls = p.classifications.find_by_country_id(@c.id)
        expect(cls.tariff_records.size).to eq(1)
        tr = cls.tariff_records.find_by_line_number 1
        expect(tr.hts_1).to eq "1234567891"
        expect(tr.hts_2).to eq "1234567892"
        expect(tr.hts_3).to eq "1234567893"
      end
      it "should update existing hts" do
        Factory(:official_tariff,:country=>@c,:hts_code=>"1234567899")
        tr = Factory(:tariff_record,classification:Factory(:classification,country:@c),hts_1:'0000000000')
        mf = ModelField.find_by_uid "*fhts_1_#{@c.id}"
        mf.process_import tr.product, '1234567899', User.new
        tr.product.save!
        tr.reload
        expect(tr.hts_1).to eq '1234567899'
      end
      it "should strip non numerics from hts" do
        Factory(:official_tariff,:country=>@c,:hts_code=>"1234567899")
        p = Factory(:product)
        mf = ModelField.find_by_uid "*fhts_1_#{@c.id}"
        mf.process_import p, '1234.567-899 ', User.new
        expect(p.classifications.first.tariff_records.first.hts_1).to eq '1234567899'
      end
      it "should not allow import of invalid HTS" do
        Factory(:official_tariff,:country=>@c,:hts_code=>"1234567899")
        p = Factory(:product)
        mf = ModelField.find_by_uid "*fhts_1_#{@c.id}"
        r = mf.process_import p, '0000000000', User.new
        expect(r).to eq "0000000000 is not valid for ZY HTS 1"
      end
      it "should allow any HTS for country withouth official tariffs" do
        p = Factory(:product)
        mf = ModelField.find_by_uid "*fhts_1_#{@c.id}"
        r = mf.process_import p, '0000000000', User.new
        expect(p.classifications.first.tariff_records.first.hts_1).to eq '0000000000'
      end
      it "should format export" do
        tr = Factory(:tariff_record,classification:Factory(:classification,country:@c),hts_1:'0000000000')
        mf = ModelField.find_by_uid "*fhts_1_#{@c.id}"
        expect(mf.process_export(tr.product,nil,true)).to eq '0000000000'.hts_format
      end
      it "should work with query" do
        u = Factory(:master_user)
        tr = Factory(:tariff_record,classification:Factory(:classification,country:@c),hts_1:'0000000000')
        ss = SearchSetup.new(module_type:'Product')
        ss.search_columns.build(model_field_uid:"*fhts_1_#{@c.id}",rank:1)
        ss.search_criterions.build(model_field_uid:"*fhts_1_#{@c.id}",operator:'eq',value:'0000000000')
        h = SearchQuery.new(ss,u).execute
        expect(h.size).to eq(1)
        expect(h.first[:row_key]).to eq tr.product.id
        expect(h.first[:result].first).to eq '0000000000'.hts_format
      end
    end
    context "bill of materials" do
      before :each do
        @parent_mf = ModelField.find_by_uid :prod_bom_parents
        @child_mf = ModelField.find_by_uid :prod_bom_children
      end
      it "should not allow imports for parents" do
        p = Factory(:product)
        r = @parent_mf.process_import p, 'abc', User.new
        expect(p).not_to be_on_bill_of_materials
        expect(r).to match(/ignored/)
      end
      it "process_export should return csv of BOM parents" do
        parent1 = Factory(:product,:unique_identifier=>'bomc1')
        parent2 = Factory(:product,:unique_identifier=>'bomc2')
        child = Factory(:product)
        child.bill_of_materials_parents.create!(:parent_product_id=>parent1.id,:quantity=>1)
        child.bill_of_materials_parents.create!(:parent_product_id=>parent2.id,:quantity=>1)
        output = @parent_mf.process_export child, nil, true
        expect(output).to eq "#{parent1.unique_identifier},#{parent2.unique_identifier}"
      end
      it "qualified_field_name should return csv of BOM parents" do
        parent1 = Factory(:product,:unique_identifier=>'bomc1')
        parent2 = Factory(:product,:unique_identifier=>'bomc2')
        child = Factory(:product)
        child.bill_of_materials_parents.create!(:parent_product_id=>parent1.id,:quantity=>1)
        child.bill_of_materials_parents.create!(:parent_product_id=>parent2.id,:quantity=>1)
        r = ActiveRecord::Base.connection.execute "SELECT #{@parent_mf.qualified_field_name} FROM products where id = #{child.id}"
        expect(r.first.first).to eq "#{parent1.unique_identifier},#{parent2.unique_identifier}"
      end
      it "should not allow imports for children" do
        p = Factory(:product)
        r = @child_mf.process_import p, 'abc', User.new
        expect(p).not_to be_on_bill_of_materials
        expect(r).to match(/ignored/)
      end
      it "should return csv of BOM children" do
        child1 = Factory(:product,:unique_identifier=>'bomc1')
        child2 = Factory(:product,:unique_identifier=>'bomc2')
        parent = Factory(:product)
        parent.bill_of_materials_children.create!(:child_product_id=>child1.id,:quantity=>1)
        parent.bill_of_materials_children.create!(:child_product_id=>child2.id,:quantity=>1)
        output = @child_mf.process_export parent, nil, true
        expect(output).to eq "#{child1.unique_identifier},#{child2.unique_identifier}"
      end
      it "qualified_field_name should return csv of BOM children" do
        child1 = Factory(:product,:unique_identifier=>'bomc1')
        child2 = Factory(:product,:unique_identifier=>'bomc2')
        parent = Factory(:product)
        parent.bill_of_materials_children.create!(:child_product_id=>child1.id,:quantity=>1)
        parent.bill_of_materials_children.create!(:child_product_id=>child2.id,:quantity=>1)
        r = ActiveRecord::Base.connection.execute "SELECT #{@child_mf.qualified_field_name} FROM products where id = #{parent.id}"
        expect(r.first.first).to eq "#{child1.unique_identifier},#{child2.unique_identifier}"
      end
    end
    context "classification count" do
      before :each do
        @user = Factory(:master_user)
        @p = Factory(:product)
        @country = Factory(:country)
        @ss = SearchSetup.new(:module_type=>'Product')
      end
      it "should reflect 0 if no classifications" do
        @ss.search_criterions.build(:model_field_uid=>'prod_class_count',:operator=>'eq',:value=>'0')
        sq = SearchQuery.new(@ss,@user)
        r = sq.execute
        expect(r.size).to eq 1
        expect(r.first[:row_key]).to eq @p.id
      end
      it "should reflect 0 with classificaton and no tariff record" do
        @p.classifications.create!(:country_id=>@country.id)
        @ss.search_criterions.build(:model_field_uid=>'prod_class_count',:operator=>'eq',:value=>'0')
        sq = SearchQuery.new(@ss,@user)
        r = sq.execute
        expect(r.size).to eq 1
        expect(r.first[:row_key]).to eq @p.id
      end
      it "should reflect 0 with no hts_1" do
        @p.classifications.create!(:country_id=>@country.id).tariff_records.create!
        @ss.search_criterions.build(:model_field_uid=>'prod_class_count',:operator=>'eq',:value=>'0')
        sq = SearchQuery.new(@ss,@user)
        r = sq.execute
        expect(r.size).to eq 1
        expect(r.first[:row_key]).to eq @p.id
      end
      it "should reflect proper count with mixed bag" do
        @p.classifications.create!(:country_id=>@country.id).tariff_records.create! # = 0
        country_2 = Factory(:country)
        @p.classifications.create!(:country_id=>country_2.id).tariff_records.create!(:hts_1=>'123') # = 1
        @p.classifications.find_by_country_id(country_2.id).tariff_records.create!(:hts_1=>'123') # = 0 don't add for second component of same classification
        @p.classifications.create!(:country_id=>Factory(:country).id).tariff_records.create!(:hts_1=>'123') # = 1
        @ss.search_criterions.build(:model_field_uid=>'prod_class_count',:operator=>'eq',:value=>'2')
        sq = SearchQuery.new(@ss,@user)
        r = sq.execute
        expect(r.size).to eq 1
        expect(r.first[:row_key]).to eq @p.id
      end
    end
    context "class_comp_cnt" do
      it "should get count of tariff rows" do
        tr = Factory(:tariff_record,line_number:1)
        Factory(:tariff_record,line_number:2,classification:tr.classification)
        cl = Classification.first
        mf = ModelField.find_by_uid :class_comp_cnt
        expect(mf.process_export(cl,nil,true)).to eq 2
        sc = SearchCriterion.new(model_field_uid: :class_comp_cnt, operator:'eq',value:'2')
        expect(sc.apply(Classification.scoped).first).to eq tr.classification
      end
    end
    context "regions" do
      it "should create classification count model fields for existing regions" do
        r = Factory(:region)
        r2 = Factory(:region)
        ModelField.reload
        expect(ModelField.find_by_region(r).size).to eq(1)
        expect(ModelField.find_by_region(r2).size).to eq(1)
      end
      context "classification count field methods" do
        before :each do
          @reg = Region.create!(:name=>"EMEA")
          @mf = ModelField.find_by_uid "*r_#{@reg.id}_class_count"
          @p = Factory(:product)
          @c1 = Factory(:country)
          @c2 = Factory(:country)
          @reg.countries << @c1
          tr1 = Factory(:tariff_record,:hts_1=>'12345678',:classification=>Factory(:classification,:country=>@c1,:product=>@p))
          tr2 = Factory(:tariff_record,:hts_1=>'12345678',:classification=>Factory(:classification,:country=>@c2,:product=>@p))
          @sc = SearchCriterion.new(:model_field_uid=>@mf.uid,:operator=>'eq',:value=>"1")

          #don't find this product because it's classified for a different country
          Factory(:tariff_record,:hts_1=>'12345678',:classification=>Factory(:classification,:country=>@c2))
        end
        it "should have proper label" do
          expect(@mf.label).to eq "Classification Count - EMEA"
        end
        it "should only count countries in region" do
          expect(@mf.process_export(@p,User.new,true)).to eq 1
          x = @sc.apply(Product.where("1"))
          x = x.uniq
          expect(x.product.size).to eq(1)
          expect(x.first).to eq @p
        end
        it "should return products without classification for eq 0" do
          @p.classifications.destroy_all
          @sc.value = "0"
          x = @sc.apply(Product.where("1"))
          expect(x.first).to eq @p
        end
        it "should not import" do
          expect(@mf.process_import(@p,1, User.new)).to match(/ignored/)
        end
        it "should not count tariff records without hts_1 values" do
          @p.classifications.find_by_country_id(@c1.id).tariff_records.first.update_attributes(:hts_1=>'')
          expect(@sc.apply(Product.where("1")).first).to be_nil
        end
        it "should not double count multiple tariff records for country" do
          @p.classifications.find_by_country_id(@c1.id).tariff_records.create!(:hts_1=>'987654321')
          x = @sc.apply(Product.where("1")).uniq
          expect(x.product.size).to eq(1)
          expect(x.first).to eq @p
        end
      end
    end
    context "PMS Month" do
      before :each do
        @ent = Factory(:entry,:monthly_statement_due_date=>Date.new(2012,9,1))
        @mf = ModelField.find_by_uid :ent_statement_month
      end
      it "should export month" do
        expect(@mf.process_export(@ent,nil,true)).to eq 9
      end
      it "should work as search criterion" do
        sc = SearchCriterion.new(:model_field_uid=>'ent_statement_month',:operator=>'eq',:value=>'9')
        Factory(:entry,:monthly_statement_due_date=>Date.new(2012,10,1))
        r = sc.apply(Entry.where('1=1'))
        expect(r.entries.size).to eq(1)
        expect(r.first).to eq @ent
      end
    end
    context "Sync Records" do
      before :each do
        @ent = Factory(:entry)
      end
      it "should show problem" do
        @ent.sync_records.create!(trading_partner:'ABC',sent_at:Date.new(2014,1,1),confirmed_at:Date.new(2014,1,2),failure_message:'PROBLEM')
        expect(ModelField.find_by_uid(:ent_sync_problems).process_export(@ent,nil,true)).to be_truthy
        sc = SearchCriterion.new(:model_field_uid=>'ent_sync_problems',operator:'eq',value:'true')
        expect(sc.apply(Entry).to_a).to eq [@ent]
      end
      it "should show no problem" do
        @ent.sync_records.create!(trading_partner:'ABC',sent_at:Date.new(2014,1,1),confirmed_at:Date.new(2014,1,2))
        expect(ModelField.find_by_uid(:ent_sync_problems).process_export(@ent,nil,true)).to be_falsey
        sc = SearchCriterion.new(:model_field_uid=>'ent_sync_problems',operator:'eq',value:'false')
        expect(sc.apply(Entry).to_a).to eq [@ent]
      end
      it "should show sync record count" do
        @ent.sync_records.create!(trading_partner:'ABC',sent_at:Date.new(2014,1,1),confirmed_at:Date.new(2014,1,2))
        @ent.sync_records.create!(trading_partner:'DEF',sent_at:Date.new(2014,1,1),confirmed_at:Date.new(2014,1,2))
        expect(ModelField.find_by_uid(:ent_sync_record_count).process_export(@ent,nil,true)).to eq 2
        sc = SearchCriterion.new(:model_field_uid=>'ent_sync_record_count',operator:'eq',value:'2')
        expect(sc.apply(Entry).to_a).to eq [@ent]
      end
      it "should show latest sent date" do
        @ent.sync_records.create!(trading_partner:'ABC',sent_at:Time.zone.parse('2014-01-03'),confirmed_at:Date.new(2014,1,4))
        @ent.sync_records.create!(trading_partner:'DEF',sent_at:Time.zone.parse('2014-01-01'),confirmed_at:Date.new(2014,1,2))
        expect(ModelField.find_by_uid(:ent_sync_last_sent).process_export(@ent,nil,true)).to eq Time.zone.parse('2014-01-03')
        sc = SearchCriterion.new(:model_field_uid=>'ent_sync_last_sent',operator:'gt',value:'2014-01-02')
        expect(sc.apply(Entry).to_a).to eq [@ent]
      end
      it "should show latest confirmed date" do
        @ent.sync_records.create!(trading_partner:'ABC',sent_at:Date.new(2014,1,3),confirmed_at:Time.zone.parse('2014-01-04'))
        @ent.sync_records.create!(trading_partner:'DEF',sent_at:Date.new(2014,1,1),confirmed_at:Time.zone.parse('2014-01-02'))
        expect(ModelField.find_by_uid(:ent_sync_last_confirmed).process_export(@ent,nil,true)).to eq Time.zone.parse('2014-01-04')
        sc = SearchCriterion.new(:model_field_uid=>'ent_sync_last_confirmed',operator:'gt',value:'2014-01-03')
        expect(sc.apply(Entry).to_a).to eq [@ent]
      end
      it "should pass with nil comparison" do
        @ent.sync_records.create!(trading_partner:'ABC',sent_at:Date.new(2014,1,3),confirmed_at:Time.zone.parse('2014-01-04'))
        @ent.sync_records.create!(trading_partner:'DEF',sent_at:Date.new(2014,1,1),confirmed_at:nil)
        expect(ModelField.find_by_uid(:ent_sync_last_confirmed).process_export(@ent,nil,true)).to eq Time.zone.parse('2014-01-04')
      end

    end
    context "duty billed" do
      before :each do
        @line1 = Factory(:broker_invoice_line,:charge_amount=>10,:charge_code=>'0001')
        @line2 = Factory(:broker_invoice_line,:charge_amount=>5,:charge_code=>'0001',:broker_invoice=>@line1.broker_invoice)
        @mf = ModelField.find_by_uid :ent_duty_billed
      end
      it "should total D records at broker invoice line" do
        expect(@mf.process_export(@line1.broker_invoice.entry,nil,true)).to eq 15
      end
      it "should not include records without an 0001 charge code" do
        line3 = Factory(:broker_invoice_line,:charge_amount=>7,:charge_code=>'0099',:broker_invoice=>@line1.broker_invoice)
        expect(@mf.process_export(@line1.broker_invoice.entry,nil,true)).to eq 15
      end
      it "should work as search criterion" do
        sc = SearchCriterion.new(:model_field_uid=>'ent_duty_billed',:operator=>'eq',:value=>'15')
        expect(sc.apply(Entry.where('1=1')).first).to eq @line1.broker_invoice.entry
      end
      it "should total across multiple broker invoices for same entry" do
        ent = @line1.broker_invoice.entry
        line3 = Factory(:broker_invoice_line,:charge_amount=>20,:charge_code=>'0001',:broker_invoice=>Factory(:broker_invoice,:entry=>ent,:suffix=>'B'))
        expect(@mf.process_export(@line1.broker_invoice.entry,nil,true)).to eq 35
        sc = SearchCriterion.new(:model_field_uid=>'ent_duty_billed',:operator=>'eq',:value=>'35')
        expect(sc.apply(Entry.where('1=1')).first).to eq @line1.broker_invoice.entry
      end
      it "should only include broker invoices on the entry in question" do
        line3 = Factory(:broker_invoice_line,:charge_amount=>3,:charge_code=>'0001') #will be on different entry
        expect(@mf.process_export(@line1.broker_invoice.entry,nil,true)).to eq 15
        sc = SearchCriterion.new(:model_field_uid=>'ent_duty_billed',:operator=>'eq',:value=>'15')
        expect(sc.apply(Entry.where('1=1')).first).to eq @line1.broker_invoice.entry
      end
      it "should view if broker and can view broker invoices" do
        u = Factory(:broker_user)
        allow(u).to receive(:view_broker_invoices?).and_return(true)
        expect(@mf.can_view?(u)).to be_truthy
      end
      it "should not view if not broker" do
        u = Factory(:importer_user)
        allow(u).to receive(:view_broker_invoices?).and_return(true)
        expect(@mf.can_view?(u)).to be_falsey
      end
      it "should not view user cannot view broker invoicees" do
        u = Factory(:broker_user)
        allow(u).to receive(:view_broker_invoices?).and_return(false)
        expect(@mf.can_view?(u)).to be_falsey
      end
    end
    context "employee" do
      before(:each) do
        @mf = ModelField.find_by_uid(:ent_employee_name)
      end
      it "should not view if not broker" do
        u = Factory(:importer_user)
        expect(@mf.can_view?(u)).to be_falsey
      end
      it "should view if broker" do
        u = Factory(:broker_user)
        expect(@mf.can_view?(u)).to be_truthy
      end
    end
    context "first HTS code" do
      before :each do
        country_1 = Factory(:country,:classification_rank=>1)
        country_2 = Factory(:country,:classification_rank=>2)
        @p = Factory(:product)
        class_1 = @p.classifications.create!(:country_id=>country_1.id)
        class_2 = @p.classifications.create!(:country_id=>country_2.id)
        t_1 = class_1.tariff_records.create!(:hts_1=>'1234567890')
        t_2 = class_2.tariff_records.create!(:hts_2=>'9999999999')
        @mf = ModelField.find_by_uid :prod_first_hts
      end
      it "process_export should match first hts code for first country" do
        expect(@mf.process_export(@p, nil, true)).to eq '1234.56.7890'
      end
      it "should match on search criterion" do
        sc = SearchCriterion.new(:model_field_uid=>'prod_first_hts',:operator=>'sw',:value=>'123456')
        r = sc.apply Product.where('1=1')
        expect(r.first).to eq @p
      end
    end
    context "hts formatting" do
      it "should handle query parameters for hts formatting" do
        tr = TariffRecord.new(:hts_1=>"1234567890",:hts_2=>"0987654321",:hts_3=>"123456")
        [:hts_hts_1,:hts_hts_2,:hts_hts_3].each do |mfuid|
          mf = ModelField.find_by_uid mfuid
          export = mf.process_export tr, nil, true
          exp_for_qry = mf.process_query_parameter tr
          case mfuid
            when :hts_hts_1
              expect(export).to eq "1234.56.7890"
              expect(exp_for_qry).to eq "1234567890"
            when :hts_hts_2
              expect(export).to eq "0987.65.4321"
              expect(exp_for_qry).to eq "0987654321"
            when :hts_hts_3
              expect(export).to eq "1234.56"
              expect(exp_for_qry).to eq "123456"
            else
              fail "Should have hit one of the tests"
          end
        end
      end
    end
    describe "process_query_parameter" do
      it "should prcoess query parameters" do
        p = Product.new(:unique_identifier=>"abc")
        expect(ModelField.find_by_uid(:prod_uid).process_query_parameter(p)).to eq "abc"
      end
    end

    context "shipment_lines" do
      it "should show container number" do
        con = Factory(:container,entry:nil,container_number:'CN123')
        sl = Factory(:shipment_line,container:con)
        mf = ModelField.find_by_uid(:shpln_container_number)
        expect(mf.process_export(sl,nil,true)).to eq 'CN123'

        sc = SearchCriterion.new(operator:'eq',model_field_uid:'shpln_container_number',value:'CN123')
        expect(sc.apply(Shipment).to_a).to eq [sl.shipment]
      end
      it "should show container size" do
        con = Factory(:container,entry:nil,container_size:'40HC')
        sl = Factory(:shipment_line,container:con)
        mf = ModelField.find_by_uid(:shpln_container_size)
        expect(mf.process_export(sl,nil,true)).to eq '40HC'

        sc = SearchCriterion.new(operator:'eq',model_field_uid:'shpln_container_size',value:'40HC')
        expect(sc.apply(Shipment).to_a).to eq [sl.shipment]
      end
      context "container_uid" do
        before :each do
          @mf = ModelField.find_by_uid(:shpln_container_uid)
        end
        it "should show container uid" do
          con = Factory(:container,entry:nil)
          sl = Factory(:shipment_line,container:con)
          expect(@mf.process_export(sl,nil,true)).to eq con.id

          sc = SearchCriterion.new(operator:'eq',model_field_uid:'shpln_container_uid',value:con.id.to_s)
          expect(sc.apply(Shipment).to_a).to eq [sl.shipment]
        end
        it "should not allow you to set a container that is already on a different shipment" do
          con = Factory(:container,shipment:Factory(:shipment))
          sl = Factory(:shipment_line)
          expect(@mf.process_import(sl,con.id, User.new)).to eq "Container with ID #{con.id} not found. Ignored."
          sl.reload
          expect(sl.container).to be_nil
        end
        it "should allow you to set a container that is already on the shipment" do
          sl = Factory(:shipment_line)
          con = Factory(:container,entry:nil,shipment:sl.shipment)
          expect(@mf.process_import(sl,con.id, User.new)).to eq "#{@mf.label(false)} set to #{con.id}."
          sl.save!
          sl.reload
          expect(sl.container).to eq con
        end
      end
    end

    context "broker_invoice_total" do
      before :each do
        MasterSetup.get.update_attributes(:broker_invoice_enabled=>true)
      end
      it "should allow you to see broker_invoice_total if you can view broker_invoices" do
        u = Factory(:user,:broker_invoice_view=>true,:company=>Factory(:company,:master=>true))
        expect(ModelField.find_by_uid(:ent_broker_invoice_total).can_view?(u)).to be_truthy
      end
      it "should not allow you to see broker_invoice_total if you can't view broker_invoices" do
        u = Factory(:user,:broker_invoice_view=>false)
        expect(ModelField.find_by_uid(:ent_broker_invoice_total).can_view?(u)).to be_falsey
      end
    end
    context "broker security" do
      before :each do
        @broker_user = Factory(:user,:company=>Factory(:company,:broker=>true))
        @non_broker_user = Factory(:user)
      end
      it "should allow duty due date if user is broker company" do
        u = @broker_user
        expect(ModelField.find_by_uid(:ent_census_warning).can_view?(u)).to be_truthy
        expect(ModelField.find_by_uid(:bi_duty_due_date).can_view?(u)).to be_truthy
      end
      it "should not allow duty due date if user is not a broker" do
        u = @non_broker_user
        expect(ModelField.find_by_uid(:ent_census_warning).can_view?(u)).to be_falsey
        expect(ModelField.find_by_uid(:bi_duty_due_date).can_view?(u)).to be_falsey
      end
      it "should secure error_free_release" do
        mf = ModelField.find_by_uid(:ent_error_free_release)
        expect(mf.can_view?(@broker_user)).to be_truthy
        expect(mf.can_view?(@non_broker_user)).to be_falsey
      end
      it "should secure census warning" do
        mf = ModelField.find_by_uid(:ent_census_warning)
        expect(mf.can_view?(@broker_user)).to be_truthy
        expect(mf.can_view?(@non_broker_user)).to be_falsey
      end
      it "should secure pdf count" do
        mf = ModelField.find_by_uid(:ent_pdf_count)
        expect(mf.can_view?(@broker_user)).to be_truthy
        expect(mf.can_view?(@non_broker_user)).to be_falsey
      end
      it "should secure first/last 7501 print" do
        [:ent_first_7501_print,:ent_last_7501_print].each do |id|
          mf = ModelField.find_by_uid(id)
          expect(mf.can_view?(@broker_user)).to be_truthy
          expect(mf.can_view?(@non_broker_user)).to be_falsey
        end
      end
    end
    context "product last_changed_by" do
      it "should apply search criterion properly" do
        c = Factory(:company,:master=>true)
        p = Factory(:product)
        p2 = Factory(:product)
        u1 = Factory(:user,:username=>'abcdef',:company=>c)
        u2 = Factory(:user,:username=>'ghijkl',:company=>c)
        p.update_attributes! last_updated_by: u2
        p2.update_attributes! last_updated_by: u1
        ss = Factory(:search_setup,:module_type=>'Product',:user=>u1)
        ss.search_criterions.create!(:model_field_uid=>'prod_last_changed_by',
          :operator=>'sw',:value=>'ghi')
        found = ss.search.to_a
        expect(found.product.size).to eq(1)
        expect(found.first).to eq p
      end
    end
    context "ent_rule_state" do
      before :each do
        @mf = ModelField.find_by_uid(:ent_rule_state)
      end
      it "should show worst state if multiple business_validation_results" do
        ent = Factory(:entry)
        ent.business_validation_results.create!(state:'Pass')
        ent.business_validation_results.create!(state:'Fail')
        expect(@mf.process_export(ent,nil,true)).to eq 'Fail'
        pass_sc = SearchCriterion.new(model_field_uid:'ent_rule_state',operator:'eq',value:'Pass')
        expect(pass_sc.apply(Entry).count).to eq 0
        fail_sc = SearchCriterion.new(model_field_uid:'ent_rule_state',operator:'eq',value:'Fail')
        expect(fail_sc.apply(Entry).count).to eq 1
      end
    end
    context "ent_pdf_count" do
      before :each do
        @with_pdf = Factory(:entry)
        @with_pdf.attachments.create!(:attached_content_type=>"application/pdf")
        @without_attachments = Factory(:entry)
        @with_tif = Factory(:entry)
        @with_tif.attachments.create!(:attached_content_type=>"image/tiff")
        @with_tif_and_2_pdf = Factory(:entry)
        @with_tif_and_2_pdf.attachments.create!(:attached_content_type=>"application/pdf")
        @with_tif_and_2_pdf.attachments.create!(:attached_content_type=>"application/pdf")
        @with_tif_and_2_pdf.attachments.create!(:attached_content_type=>"image/tiff")
        @mf = ModelField.find_by_uid(:ent_pdf_count)
        @u = Factory(:user,:company=>Factory(:company,:broker=>true))
      end
      it "should process_export" do
        expect(@mf.process_export(@with_pdf, @u)).to eq 1
        expect(@mf.process_export(@without_attachments, @u)).to eq 0
        expect(@mf.process_export(@with_tif, @u)).to eq 0
        expect(@mf.process_export(@with_tif_and_2_pdf, @u)).to eq 2

        @with_pdf.attachments.create!(:attached_content_type=>"application/notapdf", :attached_file_name=>"test.PDF")
        expect(@mf.process_export(@with_pdf, @u)).to eq 2
      end
      it "should search with greater than" do
        sc = SearchCriterion.new(:model_field_uid=>:ent_pdf_count,:operator=>'gt',:value=>0)
        r = sc.apply(Entry.where("1=1")).to_a
        expect(r.entries.size).to eq(2)
        expect(r).to include(@with_pdf)
        expect(r).to include(@with_tif_and_2_pdf)
      end
      it "should search with equals" do
        sc = SearchCriterion.new(:model_field_uid=>:ent_pdf_count,:operator=>'eq',:value=>0)
        r = sc.apply(Entry.where("1=1")).to_a
        expect(r.entries.size).to eq(2)
        expect(r).to include(@with_tif)
        expect(r).to include(@without_attachments)
      end
      it "should search with pdf counts based on file extension or mime type" do
        @with_pdf.attachments.create!(:attached_content_type=>"application/notapdf", :attached_file_name=>"test.PDF")

        sc = SearchCriterion.new(:model_field_uid=>:ent_pdf_count,:operator=>'eq',:value=>2)
        r = sc.apply(Entry.where("1=1")).to_a
        expect(r.entries.size).to eq(2)
        expect(r).to include(@with_pdf)
        expect(r).to include(@with_tif_and_2_pdf)
      end
    end

    context "ent_failed_business_rules" do
      before :each do
        @entry = Factory(:entry)
        @entry.business_validation_results << Factory(:business_validation_rule_result, state: "Fail", business_validation_rule: Factory(:business_validation_rule, name: "Test")).business_validation_result
        @entry.business_validation_results << Factory(:business_validation_rule_result, state: "Fail", business_validation_rule: Factory(:business_validation_rule, name: "Test")).business_validation_result
        @entry.business_validation_results << Factory(:business_validation_rule_result, state: "Fail", business_validation_rule: Factory(:business_validation_rule, name: "A Test")).business_validation_result
        @entry.business_validation_results << Factory(:business_validation_rule_result, state: "Pass", business_validation_rule: Factory(:business_validation_rule, name: "Another Test")).business_validation_result
      end

      it "lists failed business rule names on export" do
        c = Factory(:company,show_business_rules:true)
        expect(ModelField.find_by_uid(:ent_failed_business_rules).process_export(@entry, Factory(:user,company:c))).to eq "A Test\n Test"
      end

      it "finds results using failed rules as criterion" do
        sc = SearchCriterion.new(:model_field_uid=>:ent_failed_business_rules,:operator=>'co',:value=>"Test")
        r = sc.apply(Entry.where("1=1")).to_a
        expect(r).to include(@entry)
      end
    end

    context "ent_attachment_types" do
      before :each do
        @e = Factory(:entry)
        first = @e.attachments.create!(:attachment_type=>"B",:attached_file_name=>"A")
        second = @e.attachments.create!(:attachment_type=>"A",:attached_file_name=>"R")
      end

      it "lists attachments on export" do
        expect(ModelField.find_by_uid(:ent_attachment_types).process_export(@e, Factory(:master_user))).to eq "A\n B"
      end

      it "finds results using attachments as criterion" do
        sc = SearchCriterion.new(:model_field_uid=>:ent_attachment_types,:operator=>'co',:value=>"B")
        r = sc.apply(Entry.where("1=1")).to_a
        expect(r).to include(@e)
      end
    end

    context "ent_user_notes" do
      let(:user_notes) { ModelField.find_by_uid :ent_user_notes }
      let(:ent) { Factory(:entry) }
      let!(:u) { Factory(:master_user,entry_view:true) }
      let(:ss) { SearchSetup.new(module_type:'Entry',user:u) }

      it "returns user-note string with date/time adjusted to user's timezone" do
        moment = Time.utc(2016, 1, 1)
        eastern_time_str = moment.in_time_zone("Eastern Time (US & Canada)").to_s
        EntryComment.create!(entry: ent, body: "comment body", generated_at: moment, username: "NTUFNEL", public_comment: true)

        Time.use_zone("Eastern Time (US & Canada)") do
          ss.search_columns.build(model_field_uid:'ent_user_notes')
          row = SearchQuery.new(ss,u).execute.first[:result]
          eastern_time_comment = "comment body (#{eastern_time_str} - NTUFNEL)"

          # PENDING FEEDBACK FROM CIRCLE
          # expect(row.first).to eq eastern_time_comment

          export = user_notes.process_export(ent, User.integration)
          expect(export).to eq eastern_time_comment
        end
      end

      it "returns user-note string without date/time if generated_at field is NULL" do
        EntryComment.create!(entry: ent, body: "comment body", generated_at: nil, username: "NTUFNEL", public_comment: true)
        ss.search_columns.build(model_field_uid:'ent_user_notes')
        row = SearchQuery.new(ss,u).execute.first[:result]
        export = user_notes.process_export(ent, User.integration)
        expected_comment = "comment body (NTUFNEL)"

        expect(row.first).to eq expected_comment
        expect(export).to eq expected_comment
      end

    end
  end

  describe "find_by_uid" do
    it "finds a loaded model field by stringified symbol" do
      mf = ModelField.find_by_uid('ent_brok_ref')
      expect(mf.uid).to eq :ent_brok_ref
    end

    it "returns a blank model field if uid doesn't exist" do
      mf = ModelField.find_by_uid "not a model field"
      expect(mf).to be_blank
    end

    it "should not allow reload double check on test" do
      expect(ModelField).to_not receive(:reload)
      ModelField.find_by_uid "not a model field"
    end

    it "reloads model fields on an initial lookup failure" do
      expect(ModelField).to receive(:allow_reload_double_check).and_return true
      expect(ModelField).to receive(:reload).with(true)
      ModelField.find_by_uid "not a model field"
    end

    it "ensures model field lists are not stale" do
      expect(ModelField).to receive(:reload_if_stale).and_return true
      ModelField.find_by_uid "not a model field"
    end

    it "returns a blank model field if '_blank' uid used" do
      mf = ModelField.find_by_uid('_blank')
      expect(mf.uid).to eq :_blank
      expect(mf).to be_blank
    end

    it "doesn't attempt to reload if fields were stale" do
      expect(ModelField).to receive(:reload_if_stale).and_return true
      expect(ModelField).not_to receive(:reload)
      expect(ModelField.find_by_uid "not a model field").to be_blank
    end

    it "allows passing CustomDefinition object to find its model field" do
      cd = CustomDefinition.create!(label:'User',module_type:'Company',data_type: :integer)
      mf = ModelField.find_by_uid cd
      expect(mf.label).to eq "User"
    end

    it "returns constant MF associated with search column" do
      sc = Factory(:search_column, search_setup: Factory(:search_setup, module_type: "Product"))
      # When SearchColumn's MF is a constant, its model_field_uid refers to the temporary uid assigned by the front-end.
      # The "real" model_field_uid is generated dynamically by SearchColumn#model_field.
      sc.update_attributes! model_field_uid: "_const_12345", constant_field_name: "Foo"
      mf = ModelField.find_by_uid "*const_#{sc.id}"
      
      expect(mf.label).to eq "Foo"
    end
  end

  describe "add_fields" do
    it "adds standard field" do
      ModelField.add_fields CoreModule::ENTRY, [[1,:ent_brok_ref,:broker_reference, "Broker Reference",{:data_type=>:string}]]
      mf = ModelField.find_by_uid 'ent_brok_ref'
      expect(mf.try(:uid)).to eq :ent_brok_ref
    end

    it "does not add fields disabled via FieldValidatorRules" do
      FieldValidatorRule.create! module_type: "Entry", model_field_uid: 'ent_brok_ref', disabled: true

      ModelField.add_fields CoreModule::ENTRY, [[1,:ent_brok_ref,:broker_reference, "Broker Reference",{:data_type=>:string}]]
      mf = ModelField.find_by_uid 'ent_brok_ref'
      expect(mf).to be_blank
    end
  end

  context "user_custom_definition" do
    it "should create username fields when custom_definition is user" do
      cd = CustomDefinition.create!(label:'User',module_type:'Company',data_type: :integer, is_user: true)
      mf = ModelField.find_by_uid("*uf_#{cd.id}_username")
      comp = Factory(:company)
      u = Factory(:admin_user,username:'uname_test',first_name:'Joe',last_name:'Jackson') #using admin to avoid any permissions issues

      expect(mf.label).to eq 'User (Username)'

      #set the value
      mf.process_import(comp,u.username,u)
      comp.save!
      expect(comp.custom_value(cd)).to eq u.id

      #retrieve the value
      expect(mf.process_export(comp,u)).to eq u.username

      #query the value
      sc = SearchCriterion.new(model_field_uid: mf.uid, operator:'eq',value:u.username)
      Factory(:company) #don't find this one
      search_result = sc.apply(Company.scoped)
      expect(search_result.to_a).to eq [comp]
    end

    it "should create fullname fields when custom_definition is user" do
      cd = CustomDefinition.create!(label:'User',module_type:'Company',data_type: :integer, is_user: true)
      mf = ModelField.find_by_uid("*uf_#{cd.id}_fullname")
      comp = Factory(:company)
      u = Factory(:admin_user,username:'uname_test',first_name:'Joe',last_name:'Jackson') #using admin to avoid any permissions issues

      expect(mf.label).to eq 'User (Name)'

      expect(mf).to be_read_only
      comp.update_custom_value! cd, u.id
      comp.save!

      #retrieve the value
      expect(mf.process_export(comp,u)).to eq u.full_name

      #query the value
      sc = SearchCriterion.new(model_field_uid: mf.uid, operator:'eq',value:u.full_name)
      Factory(:company) #don't find this one
      search_result = sc.apply(Company.scoped)
      expect(search_result.to_a).to eq [comp]
    end
  end

  context "address_custom_definition" do
    before :each do
      @cd = CustomDefinition.create!(is_address: true, label:'Business', module_type:'Company', data_type: :integer)
      @ad = Factory(:address,name:'MyName',line_1:'234 Market St',line_2:nil,line_3:'5th Floor',city:'Philadelphia',state:'PA',postal_code:'19106',country:Factory(:country,iso_code:'US'))
      @ad.company.update_custom_value!(@cd,@ad.id)
    end

    it "should add name field" do
      mf = ModelField.find_by_uid("*af_#{@cd.id}_name")
      expect(mf.label).to eq "#{@cd.label} (Name)"

      expect(mf).to be_read_only
      expect(mf).to be_address_field
      expect(mf.process_export(@ad.company,nil,true)).to eq @ad.name

      sc = SearchCriterion.new(model_field_uid: mf.uid, operator:'eq',value:@ad.name)
      Factory(:address,name:'Not Me') #don't find this one
      search_result = sc.apply(Company.scoped)
      expect(search_result.to_a).to eq [@ad.company]
    end

    it "should add street field" do
      mf = ModelField.find_by_uid("*af_#{@cd.id}_street")
      expect(mf.label).to eq "#{@cd.label} (Street)"

      expect(mf).to be_read_only
      expect(mf).to be_address_field
      expect(mf.process_export(@ad.company,nil,true)).to eq '234 Market St 5th Floor'

      sc = SearchCriterion.new(model_field_uid: mf.uid, operator:'co',value:'Market')
      Factory(:address,line_1:'Not Me') #don't find this one
      search_result = sc.apply(Company.scoped)
      expect(search_result.to_a).to eq [@ad.company]
    end

    it "should add city field" do
      mf = ModelField.find_by_uid("*af_#{@cd.id}_city")
      expect(mf.label).to eq "#{@cd.label} (City)"

      expect(mf).to be_read_only
      expect(mf).to be_address_field
      expect(mf.process_export(@ad.company,nil,true)).to eq @ad.city

      sc = SearchCriterion.new(model_field_uid: mf.uid, operator:'eq',value:@ad.city)
      Factory(:address,city:'Not Me') #don't find this one
      search_result = sc.apply(Company.scoped)
      expect(search_result.to_a).to eq [@ad.company]
    end

    it "should add state field" do
      mf = ModelField.find_by_uid("*af_#{@cd.id}_state")
      expect(mf.label).to eq "#{@cd.label} (State)"

      expect(mf).to be_read_only
      expect(mf).to be_address_field
      expect(mf.process_export(@ad.company,nil,true)).to eq @ad.state

      sc = SearchCriterion.new(model_field_uid: mf.uid, operator:'eq',value:@ad.state)
      Factory(:address,state:'Not Me') #don't find this one
      search_result = sc.apply(Company.scoped)
      expect(search_result.to_a).to eq [@ad.company]
    end

    it "should add postal code field" do
      mf = ModelField.find_by_uid("*af_#{@cd.id}_postal_code")
      expect(mf.label).to eq "#{@cd.label} (Postal Code)"

      expect(mf).to be_read_only
      expect(mf).to be_address_field
      expect(mf.process_export(@ad.company,nil,true)).to eq @ad.postal_code

      sc = SearchCriterion.new(model_field_uid: mf.uid, operator:'eq',value:@ad.postal_code)
      Factory(:address,postal_code:'Not Me') #don't find this one
      search_result = sc.apply(Company.scoped)
      expect(search_result.to_a).to eq [@ad.company]
    end

    it "should add country iso field" do
      mf = ModelField.find_by_uid("*af_#{@cd.id}_iso_code")
      expect(mf.label).to eq "#{@cd.label} (Country ISO)"

      expect(mf).to be_read_only
      expect(mf).to be_address_field
      expect(mf.process_export(@ad.company,nil,true)).to eq @ad.country.iso_code

      sc = SearchCriterion.new(model_field_uid: mf.uid, operator:'eq',value:@ad.country.iso_code)
      Factory(:address,country:Factory(:country,iso_code:'XY')) #don't find this one
      search_result = sc.apply(Company.scoped)
      expect(search_result.to_a).to eq [@ad.company]
    end
  end

  describe "label" do
    before :each do
      ModelField.reload
    end

    it "returns the label for the field on a top level core module" do
      expect(ModelField.find_by_uid("prod_name").label).to eq "Name"
    end

    it "utilizes the label override" do
      FieldLabel.set_label "prod_name", "Override"
      expect(ModelField.find_by_uid("prod_name").label).to eq "Override"
    end

    it "forces the module name as a prefix" do
      expect(ModelField.find_by_uid("prod_name").label(true)).to eq "Product - Name"
    end

    it "returns the label for a child core module" do
      expect(ModelField.find_by_uid("ci_invoice_number").label).to eq "Invoice - Invoice Number"
    end

    it "disables the label for a child core module if instructed" do
      expect(ModelField.find_by_uid("ci_invoice_number").label(false)).to eq "Invoice Number"
    end

    it "handles blank fields" do
      expect(ModelField.find_by_uid("_blank").label).to eq "[blank]"
    end

    it "no-ops the force prefix parameter for blank fields" do
      expect(ModelField.find_by_uid("_blank").label(true)).to eq "[blank]"
    end

    it "handles disabled fields" do
      expect(ModelField.find_by_uid("notafieldname").label).to eq "[Disabled]"
    end

    it "no-ops the force prefix parameter for disabled fields" do
      expect(ModelField.find_by_uid("notafieldname").label(true)).to eq "[Disabled]"
    end

  end
end
