require 'liquid'

module OpenChain; class TemplateUtil

  def self.interpolate_liquid_string template_string, variables
    Liquid::Template.parse(template_string).render!(variables, {strict_variables: true, strict_filters: true, error_mode: :strict}).strip
  end


end; end;
