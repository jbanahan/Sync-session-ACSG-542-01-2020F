require 'test_helper'

class JoinSupportTest < ActiveSupport::TestCase

  test "set_module_chain w/o search setup" do
    class Sample
      include JoinSupport
      def module_chain
        @module_chain
      end
    end
    s = Sample.new
    s.set_module_chain Order.where("1=1") 
    mc = s.module_chain
    assert !mc.nil?
    assert mc==CoreModule::ORDER.default_module_chain
  end

  test "set_module_chain w/ search setup" do
    s = SearchSetup.create!(:module_type=>"Order",:name=>"setmctest",:user_id=>User.first.id)
    sc = s.search_criterions.create!(:model_field_uid=>"ord_ord_num",:operator=>"eq",:value=>"1")
    def sc.module_chain
      @module_chain
    end
    sc.set_module_chain nil #shouldn't need base object because it is looking up the core module from the search setup
    mc = sc.module_chain 
    assert mc==CoreModule::ORDER.default_module_chain
  end

end
