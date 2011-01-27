require 'test_helper'

class SearchSetupTest < ActiveSupport::TestCase
  # Replace this with your real tests.
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
    search_crit = base.search_criterions.create!(:condition => "eq", :value=>"10", :model_field_uid=>"prod_name")
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
    assert copy_search.condition == search_crit.condition, "Search criterion conditions were different"
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
