require 'test_helper'

class SalesOrderLineTest < ActiveSupport::TestCase

  test "locked" do
    line = SalesOrderLine.first
    assert !line.locked?, "Should not be locked at start"
    line.sales_order.customer.locked = true
    assert line.locked?, "Should be locked when customer is locked."
    line.sales_order.customer.locked = false
    line.product.vendor.locked = true
    assert line.product.locked?, "Confirming that product is locked."
    assert !line.locked?, "Line should not lock because product is locked."
  end
  
  test "set line number" do
    base = SalesOrderLine.first
    to_test = base.clone
    assert !to_test.save, "Should not save because line_number / ord_number unique test."
    to_test.line_number = nil
    to_test.set_line_number
    assert to_test.line_number > base.line_number, "New line number should be set."
    assert to_test.save, "Should save because line_number is now unique within order"
  end
end
