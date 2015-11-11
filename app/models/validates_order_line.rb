module ValidatesOrderLine
  include ValidatesEntityChildren

  def module_chain
    [CoreModule::ORDER, CoreModule::ORDER_LINE]
  end

  def child_objects order
    order.order_lines
  end

  def module_chain_entities order_line
    {CoreModule::ORDER => order_line.order, CoreModule::ORDER_LINE => order_line}
  end
end