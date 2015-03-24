require 'spec_helper'

describe OpenChain::ModelFieldRenderer::FieldHelperSupport do
  def base_object
    k = Class.new do
      include OpenChain::ModelFieldRenderer::FieldHelperSupport
    end
    k.new
  end

  describe :add_tooltip_to_html_options do
    it "should add tooltip from model field if it exists" do
      html_opts = {}
      mf = double(:model_field)
      mf.should_receive(:tool_tip).and_return 'abc'

      base_object.add_tooltip_to_html_options mf, html_opts

      expected_opts = {title:'abc',class:' fieldtip '}
      expect(html_opts).to eq expected_opts
    end
    it "should do nothing if model_field.tool_tip returns blank" do
      html_opts = {}
      mf = double(:model_field)
      mf.should_receive(:tool_tip).and_return ''

      base_object.add_tooltip_to_html_options mf, html_opts

      expect(html_opts).to be_blank
    end
  end

  describe :get_form_field_name do
    before :each do
      @mf = double(:model_field)
      @mf.stub(:uid).and_return('xx')
    end
    it "should prefix parent_name if it exists" do
      expect(base_object.get_form_field_name('abc',nil,@mf)).to eq 'abc[xx]'
    end
    it "should prefix parent_name instead of form_object name" do
      form_obj = double('form_object')
      form_obj.stub(:object_name).and_return('def')
      expect(base_object.get_form_field_name('abc',form_obj,@mf)).to eq 'abc[xx]'
    end
    it "should prefix form_object.object_name if it exists without parent_name" do
      form_obj = double('form_object')
      form_obj.stub(:object_name).and_return('def')
      expect(base_object.get_form_field_name('',form_obj,@mf)).to eq 'def[xx]'
    end
    it "should just do uid if no parent_name or form_object" do
      expect(base_object.get_form_field_name('',nil,@mf)).to eq 'xx'
    end
  end

  describe :get_core_and_form_objects do
    it "should return core object and return nil for form_object when core_object is passed" do
      obj = Order.new
      expect(base_object.get_core_and_form_objects(obj)).to eq [obj,nil]
    end
    it "should return core and form_objects when form_object is passed" do
      frm = double(:form)
      frm.stub(:fields_for).and_return('x')
      obj = Order.new
      frm.stub(:object).and_return(obj)
      expect(base_object.get_core_and_form_objects(frm)).to eq [obj,frm]
    end
  end

  describe :get_model_field do
    before :each do
      @expected = ModelField.find_by_uid(:ord_ord_num)
    end
    it "should accept symbol" do
      expect(base_object.get_model_field(:ord_ord_num)).to eq @expected
    end
    it "should accept string" do
      expect(base_object.get_model_field('ord_ord_num')).to eq @expected
    end
    it "should accept ModelField object" do
      expect(base_object.get_model_field(@expected)).to eq @expected
    end
  end

  describe :for_model_fields do
    it "should loop and yield ModelField objects for mixed array of strings, symbols, and ModelField objects" do
      vals = [:ord_ord_num, ModelField.find_by_uid(:ord_ord_date),'ord_cust_ord_no']
      expected = [:ord_ord_num,:ord_ord_date,:ord_cust_ord_no].collect {|uid| ModelField.find_by_uid(uid)}

      received = []
      base_object.for_model_fields(vals) {|mf| received << mf}

      expect(received).to eq expected
    end
    it "should yield for single object" do
      val = :ord_ord_num
      expected = [ModelField.find_by_uid(:ord_ord_num)]

      received = []
      base_object.for_model_fields(val) {|mf| received << mf}

      expect(received).to eq expected
    end
  end

  describe :skip_field? do
    before :each do
      @model_field = double(:model_field)
      @model_field.stub(:can_view?).and_return(true)
      @model_field.stub(:user_field?).and_return(false)
      @user = double(:user)
    end
    it "should skip user fields" do
      @model_field.stub(:user_field?).and_return(true)
      expect(base_object.skip_field?(@model_field,@user,false,false)).to be_true
    end
    it "should not skip if hidden override" do
      expect(base_object.skip_field?(@model_field,@user,true,false)).to be_false
    end
    it "should skip if user doesn't have view permission" do
      @model_field.stub(:can_view?).and_return(false)
      expect(base_object.skip_field?(@model_field,@user,false,false)).to be_true
    end
    it "should skip if user does have view permission and read_only_override is false and the field is read only" do
      @model_field.stub(:read_only?).and_return(true)
      expect(base_object.skip_field?(@model_field,@user,false,false)).to be_true
    end
    it "should skip if user does have view permission and read_only_override is false and the field is not read only and the user cannot edit the field" do |variable|
      @model_field.stub(:read_only?).and_return(false)
      @model_field.stub(:can_edit?).and_return(false)
      expect(base_object.skip_field?(@model_field,@user,false,false)).to be_true
    end
    it "should not skip if user does have view permission and read_only_override is true" do
      expect(base_object.skip_field?(@model_field,@user,false,true)).to be_false
    end
  end
end
