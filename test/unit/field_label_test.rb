require 'test_helper'

class FieldLabelTest < ActiveSupport::TestCase

  def teardown #make sure label_cache is cleared
    FieldLabel::LABEL_CACHE.clear
  end

  test "set_label" do
    expected_label = "abc123"
    mfuid = "fake_mfuid"
    
    #confirm round trip (don't worry about database save)
    assert FieldLabel.label_text(mfuid).nil?, "Should not have found anything yet, found #{FieldLabel.label_text(mfuid)}"
    FieldLabel.set_label mfuid, expected_label
    found = FieldLabel.label_text(mfuid)
    assert expected_label==found, "Should have found #{expected_label}, found #{found}"

    #confirm database save
    found = FieldLabel.where(:model_field_uid=>mfuid).first.label
    assert expected_label==found, "Should have found #{expected_label} in database, found #{found}"

    #make sure second call doesn't hit database again
    FieldLabel.expects(:where).never
    found = FieldLabel.label_text(mfuid)
    assert expected_label==found, "Should have found #{expected_label} without hitting database, found #{found}"
  end

  test "find in default cache" do
    expected_label = "Unique Identifier" 
    assert !expected_label.nil?
    assert FieldLabel::LABEL_CACHE[:prod_uid].nil? #not in the standard label cache
    assert FieldLabel.where(:model_field_uid=>"prod_uid").first.nil? #not in the database
    assert FieldLabel.label_text("prod_uid")==expected_label, "Expected #{expected_label}, got #{FieldLabel.label_text "prod_uid"}"
  end

  test "find for custom field" do
    expected_label = "my custom label"
    cd = CustomDefinition.create!(:label=>expected_label,:data_type=>"string",:module_type=>"Order")
    mfuid = "*cf_#{cd.id}"
    found = FieldLabel.label_text mfuid
    assert found==expected_label, "Should have found #{expected_label}, found #{found}"
    found = FieldLabel::LABEL_CACHE[mfuid.to_sym] #exists in cache
    assert found==expected_label, "Expected to find #{expected_label}, found #{found}"
    CustomDefinition.expects(:where).never #should not hit database on second cal
    found = FieldLabel.label_text mfuid
    assert found==expected_label
  end

  test "resets - custom" do
    cd_exp = "custom_label"
    cd = CustomDefinition.create!(:label=>cd_exp,:data_type=>"string",:module_type=>"Product")
    cd_mfuid = "*cf_#{cd.id}"
    found = FieldLabel.label_text cd_mfuid
    assert found == cd_exp
    assert FieldLabel::LABEL_CACHE[cd_mfuid.to_sym]==cd_exp #making sure the cache was created
    new_cd_exp = "new custom label"
    cd.label = new_cd_exp
    cd.save! #should reset the FieldLabel cache in a callback
    found = FieldLabel.label_text cd_mfuid
    assert found == new_cd_exp
  end

  test "resets - standard" do
    exp = "my field label"
    mf_uid = "prod_uid"
    FieldLabel.set_label mf_uid, exp
    assert FieldLabel.label_text(mf_uid)==exp
    assert FieldLabel::LABEL_CACHE[mf_uid.to_sym]==exp #making sure the cache was creaetd
    new_exp = "my new field label"
    FieldLabel.set_label mf_uid, new_exp
    assert FieldLabel.label_text(mf_uid)==new_exp
  end

end
