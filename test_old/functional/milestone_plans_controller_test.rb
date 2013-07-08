require 'test_helper'
require 'authlogic/test_case'

class MilestonePlansControllerTest < ActionController::TestCase
  setup :activate_authlogic
  fixtures :users

  test "remove milestone" do
    UserSession.create(users(:adminuser))
    cd = CustomDefinition.create!(:module_type=>"Order",:data_type=>:date,:label=>"mydef")
    mp = MilestonePlan.create!(:name=>"rm")
    mdo = mp.milestone_definitions.create!(:model_field_uid=>:ord_ord_date)
    mds = mp.milestone_definitions.create!(:model_field_uid=>:sale_order_date,:previous_milestone_definition_id=>mdo.id,:days_after_previous=>3)
    form_hash = {
      :id => mp.id,
      :milestone_plan => {
        :name=>"rm",
        :milestone_definitions_attributes=> {
          '1' => {:model_field_uid=>"ord_ord_date",:display_rank=>0}
        }
      },
      :milestone_definition_rows => {
        '12345' => {:model_field_uid=>"sale_order_date",:previous_model_field_uid=>"ord_ord_date",:days_after_previous=>4,:display_rank=>1,:destroy=>"true"},
        '54321' => {:model_field_uid=>"*cf_#{cd.id}",:days_after_previous=>99,:previous_model_field_uid=>"ord_ord_date",:display_rank=>2}
      }
    }
    post :update, form_hash
    assert_response :redirect

    mp = MilestonePlan.find(mp.id)
    assert_equal 2, mp.milestone_definitions.size
    assert_nil MilestoneDefinition.where(:id=>mds.id).first #should have been deleted
    found_cd = mp.milestone_definitions.where(:model_field_uid=>"*cf_#{cd.id}").first
    assert_not_nil found_cd
    assert_equal 99, found_cd.days_after_previous
    assert_equal mdo.id, found_cd.previous_milestone_definition_id
  end
  test "create milestone" do 
    cd = CustomDefinition.create!(:module_type=>"Order",:data_type=>:date,:label=>"mydef")

    UserSession.create(users(:adminuser))
    form_hash = {
      :milestone_plan=> {
        :name=>"my name",
        :milestone_definitions_attributes=> {
          '1'=> {:model_field_uid=>"ord_ord_date",:display_rank=>0}
        }
      },
      :milestone_definition_rows => {
        '1' => {:model_field_uid=>"sale_order_date",:days_after_previous=>"5",:previous_model_field_uid=>"ord_ord_date",:final_milestone=>'true',:display_rank=>1},
        '9954645464546' => {:model_field_uid=>"*cf_#{cd.id}",:days_after_previous=>"7",:previous_model_field_uid=>"sale_order_date",:display_rank=>2}
      }
    }
    put :create, form_hash
    assert_response :redirect
    mp = MilestonePlan.where(:name=>"my name").first
    assert_not_nil mp
    assert_equal 3, mp.milestone_definitions.size
    mp.milestone_definitions.each do |md|
      case md.model_field_uid
      when 'ord_ord_date'
        assert_nil md.previous_milestone_definition_id
        assert_equal "ord_ord_date", md.model_field_uid
        assert_equal 0, md.display_rank
        assert !md.final_milestone
      when 'sale_order_date'
        assert_equal mp.milestone_definitions.where(:previous_milestone_definition_id=>nil).first.id, md.previous_milestone_definition_id
        assert_equal 5, md.days_after_previous
        assert_equal 1, md.display_rank
        assert md.final_milestone?
      when "*cf_#{cd.id}"
        assert_equal mp.milestone_definitions.where(:model_field_uid=>"sale_order_date").first.id, md.previous_milestone_definition_id
        assert_equal 7, md.days_after_previous
        assert_equal 2, md.display_rank
        assert !md.final_milestone?
      end
    end
    assert_redirected_to edit_milestone_plan_url(mp)
  end

  test "view" do 
  
    mp = MilestonePlan.create!(:name=>"abcd")

    UserSession.create(users(:adminuser))
      
    get :edit, {:id=>mp.id}
    assert_response :success

  end

  test "view - no permission" do 

    mp = MilestonePlan.create!(:name=>"abcd")

    UserSession.create(users(:vendoruser))

    get :edit, {:id=>mp.id}
    assert_response :redirect
    assert flash[:errors].include?("Only administrators can do this.")
  end
end
