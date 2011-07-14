require 'test_helper'
require 'authlogic/test_case'

class MilestonePlansControllerTest < ActionController::TestCase
  setup :activate_authlogic
  fixtures :users

  test "create milestone" do 
    cd = CustomDefinition.create!(:module_type=>"Order",:data_type=>:date,:label=>"mydef")

    UserSession.create(users(:adminuser))
    form_hash = {
      :milestone_plan=> {
        :name=>"my name",
        :milestone_definitions_attributes=> {
          '1'=> {:model_field_uid=>"ord_ord_date"}
        }
      },
      :milestone_definition_rows => {
        '1' => {:model_field_uid=>"sale_order_date",:days_after_previous=>"5",:previous_model_field_uid=>"ord_ord_date",:final_milestone=>'true'},
        '9954645464546' => {:model_field_uid=>"*cf_#{cd.id}",:days_after_previous=>"7",:previous_model_field_uid=>"sale_order_date"}
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
        assert !md.final_milestone
      when 'sale_order_date'
        assert_equal mp.milestone_definitions.where(:previous_milestone_definition_id=>nil).first.id, md.previous_milestone_definition_id
        assert_equal 5, md.days_after_previous
        assert md.final_milestone?
      when "*cf_#{cd.id}"
        assert_equal mp.milestone_definitions.where(:model_field_uid=>"sale_order_date").first.id, md.previous_milestone_definition_id
        assert_equal 7, md.days_after_previous
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
