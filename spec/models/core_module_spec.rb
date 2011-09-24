require 'spec_helper'

describe CoreModule do

  it 'should return class by calling klass' do
    CoreModule::PRODUCT.klass.should be Product
  end

end
