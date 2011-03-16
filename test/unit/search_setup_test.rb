require 'test_helper'

class SearchSetupTest < ActiveSupport::TestCase

  test "uploadable - Shipment, Delivery, Sales Order = False" do
    s = SearchSetup.new(:module_type=>CoreModule::SHIPMENT.class_name)
    m = []
    assert !s.uploadable?(m), "Shipment uploadable should have returned false."
    assert m.length==1 && m[0] == "Uploads are not supported for Shipments at this time.", "Shipment message missing."
    s.module_type = CoreModule::DELIVERY.class_name
    m = []
    assert !s.uploadable?(m), "delivery uploadable should have returned false."
    assert m.length==1 && m[0] == "Uploads are not supported for Deliveries at this time.", "delivery message missing."
    s.module_type = CoreModule::SALE.class_name
    m = []
    assert !s.uploadable?(m), "Sales Order uploadable should have returned false."
    assert m.length==1 && m[0] == "Uploads are not supported for Sales at this time.", "Sales Order message missing."
  end

  test "uploadable - Order" do
    s = SearchSetup.create!(:module_type=>CoreModule::ORDER.class_name, :name=>"uploadable - order",:user_id => users(:vendoruser).id)

    m = []
    assert !s.uploadable?(m), "Should not upload without required fields or as vendor. Messages: #{m}"
    assert m.length==3, "Messages length should have been 3, was #{m.length}"
    assert m.include?("You do not have permission to edit Orders."), "Permission missing. Messages: #{m}"
    assert m.include?("Order Number field is required to upload Orders."), "Order Number required missing. Messages: #{m}"
    assert m.include?("Vendor Name or Vendor ID is required to upload Orders."), "Vendor required missing. Messages: #{m}"

    s.user = users(:masteruser)
    s.save!
    s.search_columns.create!(:model_field_uid=>"ord_ord_num",:rank=>0)
    s.search_columns.create!(:model_field_uid=>"ord_ven_name",:rank=>1)

    m = []
    assert s.uploadable?(m), "Should upload, didn't. Messages #{m}"

    s.search_columns.create!(:model_field_uid=>"ordln_ordered_qty",:rank=>2)

    m = []
    assert !s.uploadable?(m), "Shouldn't upload without required Order Line fields. Messages: #{m}"
    assert m.length==2, "Messages length should have been 2, was #{m.length}"
    assert m.include?("Line - Line Number is required to upload Order Lines."), "Line number required missing. Messages: #{m}"
    assert m.include?("Line - Product Unique Identifier is required to upload Order Lines."), "PUID required missing. Messages: #{m}"

    s.search_columns.create!(:model_field_uid=>"ordln_line_number",:rank=>3)
    s.search_columns.create!(:model_field_uid=>"ordln_puid",:rank=>4)
    
    m = []
    assert s.uploadable?(m), "Should upload with order line. Messages: #{m}"
  end

  test "uploadable - Product" do
    s = SearchSetup.create!(:module_type=>CoreModule::PRODUCT.class_name, :name=>"uploadable - product",:user_id => users(:vendoruser).id)
    
    m = []
    assert !s.uploadable?(m), "Should not upload without required fields or as vendor. Messages: #{m}"
    assert m.length==3, "Messages length should have been 3, was #{m.length}"
    assert m.include?("You do not have permission to edit Products."), "Permission missing. Messages: #{m}"
    assert m.include?("Unique Identifier field is required to upload Products."), "UID required missing. Messages: #{m}"
    assert m.include?("Vendor Name or Vendor ID is required to upload Products."), "Vendor requireed missing. Messages: #{m}"

    s.search_columns.create!(:model_field_uid=>"prod_uid",:rank=>0)
    s.search_columns.create!(:model_field_uid=>"prod_ven_name",:rank=>1)
    s.user=users(:masteruser)
    s.save!

    m = []
    assert s.uploadable?(m), "Should upload, didn't. Messages: #{m}"

    ht = s.search_columns.create!(:model_field_uid=>"hts_hts_1",:rank=>2)
    
    m = []
    assert !s.uploadable?(m), "shouldn't upload with HTS and no row or classification. Messages: #{m}"
    assert m.include?("To include Tariff fields, you must also include the Classification Country Name or ISO code."), "Classification required missing. Messages: #{m}"
    assert m.include?("To include Tariff fields, you must also include the Tariff Row."), "Tariff Row required missing. Messages: #{m}"
    
    ccn = s.search_columns.create!(:model_field_uid=>"class_cntry_name",:rank=>3)
    hn = s.search_columns.create!(:model_field_uid=>"hts_line_number",:rank=>4)

    m = [] 
    assert s.uploadable?(m), "Should upload with tariff & classification, didn't. Messages: #{m}"
    
    [ccn,hn,ht].each {|c| c.destroy} #clear fields that would make this pass
    s = SearchSetup.find(s.id)

    cd = CustomDefinition.create!(:label=>"test classification field",:data_type=>"string",:module_type=>"Classification")
    s.search_columns.create!(:model_field_uid=>"*cf_#{cd.id}",:rank=>3)
    assert s.search_columns.size==3, "Confirming setup, search columns size should be 3, was #{s.search_columns.size}"
    m = []
    assert !s.uploadable?(m), "Should not upload with classification and no country."
    assert m.include?("To include Classification fields, you must also include the Classification Country Name or ISO code."), "Missing Classification Country msg. Messages: #{m}"

    s.search_columns.create!(:model_field_uid=>"class_cntry_iso",:rank=>4)
    m = []
    assert s.uploadable?(m), "Should upload with classification & country, didn't. Messages: #{m}"
  end

  test "touch" do
    s = SearchSetup.new(:name => "touch test",:user => User.first,:module_type=>"Product")
    assert s.last_accessed.nil?, "last accessed should not have been touched"
    s.touch
    assert s.last_accessed > 3.seconds.ago, "Last accessed should be just now."
    assert s.id.nil?, "Should not have saved"
    s.last_accessed = 1.day.ago
    s.touch(true)
    assert s.last_accessed > 3.seconds.ago, "Last accessed should be just now."
    assert !s.id.nil?, "Should have saved"
  end
  
  test "for user scope" do
    name = "for user scope name"
    s1 = SearchSetup.create!(:name => name,:user => User.find(1), :module_type=>"Product")
    s2 = SearchSetup.create!(:name => name,:user => User.find(2), :module_type=>"Product")
    result = SearchSetup.for_user(User.find(1)).where(:name=>name)
    assert result.length==1, "Should only find one"
    assert result.first==s1
  end
  
  test "for module scope" do 
    name = "for module_scope"
    s1 = SearchSetup.create!(:name => name,:user => User.find(1), :module_type=>"Product")
    s2 = SearchSetup.create!(:name => name,:user => User.find(1), :module_type=>"Order")
    result = SearchSetup.for_module(CoreModule::PRODUCT).where(:name=>name)
    assert result.length==1, "Should only find one"
    assert result.first==s1
  end
  
  test "deep copy" do
    base = SearchSetup.create!(:name => "deep copy test", :user => User.find(1), :module_type=>"Product")
    search_crit = base.search_criterions.create!(:operator => "eq", :value=>"10", :model_field_uid=>"prod_name")
    sort_crit = base.sort_criterions.create!(:rank=>5,:model_field_uid=>"prod_ven",:descending=>true)
    search_col = base.search_columns.create!(:rank=>0,:model_field_uid=>"prod_ven_name")
    base.deep_copy("new name",true)
    copy = SearchSetup.where(:name=>"new name").first
    assert copy.id != base.id, "IDs were the same"
    assert copy.user==base.user, "Users were different"
    assert copy.module_type == base.module_type, "Module types different"
    assert copy.search_criterions.length==base.search_criterions.length, "Search criterions length were different"
    copy_search = copy.search_criterions.first
    assert copy_search.id != search_crit.id, "Search criterion ids were the same."
    assert copy_search.operator == search_crit.operator, "Search criterion operators were different"
    assert copy_search.value == search_crit.value, "Search criterion values were different"
    assert copy_search.model_field_uid == search_crit.model_field_uid, "Search criterion model_field_uids were different"
    assert copy.sort_criterions.length==base.sort_criterions.length, "Sort criterions length were different"
    copy_sort = copy.sort_criterions.first
    assert copy_sort.id != sort_crit.id, "Sort criterion ids were the same"
    assert copy_sort.model_field_uid==sort_crit.model_field_uid, "Sort criterion model_field_uids were different"
    assert copy_sort.rank==sort_crit.rank, "Sort criterion ranks were different"
    assert copy_sort.descending==sort_crit.descending, "Sort criterion descending were different"
    assert copy.search_columns.length==base.search_columns.length, "Sort column lengths were different"
    copy_col = copy.search_columns.first
    assert copy_col.id != sort_crit.id, "Search column ids were the same"
    assert copy_col.model_field_uid==search_col.model_field_uid, "Search column model_field_uids were different"
    assert copy_col.rank==search_col.rank, "Search column ranks were different"
  end
end
