require 'test_helper'

class ModuleChainTest < ActiveSupport::TestCase

  test "parent" do
    m = ModuleChain.new
    m.add_array [CoreModule::ORDER,CoreModule::PRODUCT,CoreModule::DELIVERY]
    assert m.parent(CoreModule::DELIVERY)==CoreModule::PRODUCT
    assert m.parent(CoreModule::PRODUCT)==CoreModule::ORDER
    assert m.parent(CoreModule::ORDER).nil? #return nil for first object
    assert m.parent(CoreModule::SHIPMENT).nil? #return nil for object not in list
  end
  
  test "to_a" do
    #confirm it is a clone of the internal array
    m = ModuleChain.new
    m.add CoreModule::PRODUCT
    m.add CoreModule::ORDER

    r = m.to_a
    assert r[0]==CoreModule::PRODUCT
    assert r[1]==CoreModule::ORDER
    assert r.length==2
    r.slice! 0
    assert r.length==1

    assert m.to_a.length==2

  end

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
