module PolymorphicFinders
  extend ActiveSupport::Concern

  def polymorphic_find model_name, model_id
    constantize(model_name).find model_id
  end

  def polymorphic_where model_name, model_id
    constantize(model_name).where(id: model_id)
  end

  def polymorphic_scope model_name
    constantize(model_name).all
  end

  def constantize model_name
    model_class = model_name.to_s.camelize.singularize.constantize

    if validate_polymorphic_class model_class
      model_class
    else
      raise "Invalid class name #{model_name}"
    end
  end

  def validate_polymorphic_class model_class
    # Do not use the class unless it inherits from ActiveRecord::Base
    # It's possible we could locate the source locations of several methods and see if they
    # fall inside the OpenChain directory, but doing a core module check should be 
    # good enough for now.
    # Something like this could be used to find source locations:
    # model_class.instance_methods(false).map { |m| model_class.instance_method(m).source_location.first }.uniq
    # If < is true, it means class inherits from ActiveRecord::Base

    # If more specific restrictions are required, then inheriting class can override this method
    model_class < ActiveRecord::Base
  end
end