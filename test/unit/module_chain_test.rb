require 'test_helper'

class ModuleChainTest < ActiveSupport::TestCase
  test "add, get child modules" do
    m = ModuleChain.new

    m.add CoreModule::PRODUCT
    m.add CoreModule::ORDER
    m.add CoreModule::DELIVERY

    product_children = m.child_modules(CoreModule::PRODUCT)
    assert product_children.length == 2, "Product should have two children, had #{product_children.length}"
    assert product_children[0] == CoreModule::ORDER, "Product's first child should be ORDER, was, #{product_children[0].class_name}"
    assert product_children[1] == CoreModule::DELIVERY, "Product's second child should be DELIVERY, was #{product_children[1].class_name}"

    order_children = m.child_modules(CoreModule::ORDER)
    assert order_children.length == 1, "Order should have 1 child, had #{order_children.length}"
    assert order_children[0] == CoreModule::DELIVERY, "Order's child should be DELIVERY, was #{order_children[0].class_name}"

    assert m.child_modules(CoreModule::DELIVERY).length==0, "Delivery should have no children."
  end
end
