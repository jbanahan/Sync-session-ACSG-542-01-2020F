RSpec::Matchers.define :have_xpath_value do |xpath_expression, value|
  match do |xml|
    xpath_value = REXML::XPath.first(xml, xpath_expression)

    if xpath_value.is_a?(REXML::Element)
      xpath_value = xpath_value.text
    elsif xpath_value.is_a?(REXML::Attribute)
      xpath_value = xpath_value.value
    end

    @xpath_value = xpath_value

    xpath_value == value
  end

  failure_message do |actual|
    name = nil
    if actual.is_a?(REXML::Document)
      name = "<#{actual.root.name}>"
    elsif actual.respond_to?(:name)
      name = "<#{actual.name}>"
    else
      name = actual
    end

    xpath_output = @xpath_value.nil? ? "nil" : "'#{@xpath_value}'"

    "expected '#{name}' to evalute xpath expression '#{xpath_expression}' and return '#{value}'. It was #{xpath_output}."
  end

  failure_message_when_negated do |actual|
    name = nil
    if actual.is_a?(REXML::Document)
      name = "<#{actual.root.name}>"
    elsif actual.respond_to?(:name)
      name = "<#{actual.name}>"
    else
      name = actual
    end

    "expected '#{name}' to evalute xpath expression '#{xpath_expression}' and return something other than '#{value}'."
  end
end