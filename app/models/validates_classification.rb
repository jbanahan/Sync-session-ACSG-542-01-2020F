module ValidatesClassification
  include ValidatesEntityChildren

  def module_chain
    [CoreModule::PRODUCT, CoreModule::CLASSIFICATION]
  end

  def child_objects product
    product.classifications
  end

  def module_chain_entities classification
    {CoreModule::PRODUCT => classification.product, CoreModule::CLASSIFICATION => classification}
  end

end