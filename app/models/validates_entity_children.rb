# When included, this module allows you to write business logic validations directly against a 
# child object of the base entity.  .ie you essentially don't have to repeat the looping
# logic for finding child lines.
#
# Classes including this module must implement the following methods: 

# child_objects - returns an object responding to "each" that will enumerate all the child objects of the object passed into run_validation
# that should be validated. EX: If you want to validate against invoice lines, child_objects should return an "each"able object containing
# all the commercial invoice lines from the passed in entry to validate. 
# run_child_validation - runs the actual validation check against the child level entity you're checking.  Receives and instance
# of the contents of the object returned by child_objects.
# module_chain - Returns an array of the core modules used in the validation, ordering should go from parent -> child.
# module_chain_entities - Given a value from the child_objects array, it must return a hash populated with the objects that make
# up the core module chain.
# 
# Optional:
# setup_validation - if defined, will be called prior to executing any child level validations.
# 
module ValidatesEntityChildren

  def run_validation entity
    validation_messages = []

    sc_hash = build_search_criterion_hash
    if self.respond_to?(:setup_validation)
      self.setup_validation
    end

    child_objects(entity).each do |child|
      break if defined?(@validation_stopped) && @validation_stopped == true

      if matches_all_criteria?(child, sc_hash)
        child_message = run_child_validation(child)
        validation_messages << child_message unless child_message.blank?
      end
    end

    remove_instance_variable(:@validation_stopped) if defined?(@validation_stopped)

    validation_messages.blank? ? nil : validation_messages.join("\n")
  end

  # Returns true if it is determined that none of the rule level search criterions matches
  # the parent entity data.
  def should_skip? entity
    # We can skip the validations if nothing in the entity matches the rule level search criterions
    search_criterion_hash = build_search_criterion_hash
    child_objects(entity).each do |child|
      return false if matches_all_criteria?(child, search_criterion_hash)
    end
    true
  end

  # Builds a hash containing arrays of the search criterions keyed to the Core Module they belong to.
  def build_search_criterion_hash
    criterion_hash = {}
    mc_array = module_chain
    mc_array.each {|mc| criterion_hash[mc] = []}

    self.search_criterions.each do |criterion|
      criterion_core_module = criterion.core_module
      criterion_hash[criterion_core_module] << criterion if criterion_hash.include? criterion_core_module
    end

    criterion_hash
  end

  # Returns true if the child entity you're working with matches all the defined search criterions
  # for the rule.
  def matches_all_criteria? child_entity, search_criterion_hash = nil
    search_criterion_hash = build_search_criterion_hash unless search_criterion_hash

    unless search_criterion_hash.size == 0
      module_chain_entities(child_entity).each do |core_module, obj|
        search_criterion_hash[core_module].each do |criterion|
          # Short circuit as soon as we don't match a criterion, there's no point in continuing
          # if one of the criteria failed since we're not going to evaluate the rule anyway.
          return false unless criterion.test?(obj)
        end
      end
    end

    true
  end

  # Calling this method will stop the run_validation method from continuing to iterate over and validate
  # the child entities - it will then report any existing validation messages accrewed at the time when stop is called.  
  # Utilize this method in situations where you want to stop the validation process after finding
  # an invalid condition in the child entities.
  def stop_validation
    @validation_stopped = true
  end

end