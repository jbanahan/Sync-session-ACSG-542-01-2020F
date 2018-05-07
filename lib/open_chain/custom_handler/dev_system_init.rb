# This class exists SOELY for use when functionally testing comparators locally.  It exists such so that
# we can make a change to THIS system init and not a production one to test any comparators.  Updating a production
# system init to test locally is problematic because we have had cases in the past where things were commented out or added 
# to facilitate functional testing and then never removed and accidently committed.

# This class should remain blank...but it's not a big problem if it gets committed with anything in it as it's not
# referenced by the production environment

module OpenChain; module CustomHandler; class DevSystemInit

  def self.init
    return unless Rails.env.development?

    register_change_comparators
  end

  def self.register_change_comparators

  end
  private_class_method :register_change_comparators

end; end; end