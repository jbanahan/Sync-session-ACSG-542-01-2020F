require 'digest/md5'

module OpenChain; module CustomHandler; module Polo; class PoloFiberContentParser
  include OpenChain::CustomHandler::Polo::PoloCustomDefinitionSupport

  def self.can_view? user
    MasterSetup.get.system_code == 'polo' || Rails.env.development?
  end

  # Runs the parser via the scheduler so that any fiber fields updated since the previous run are anal
  def self.run_schedulable opts = {}
    #TODO Log the runtime of this

    last_run = opts['last_run_time']
    # Regardless of whether we are using the last run time from opts or
    # from the key store, we'll store off the run time
    key = KeyJsonItem.polo_fiber_report('fiber_analysis').first_or_create! json_data: "{}"

    if last_run.nil?
      data = key.data
      last_run = data['last_run_time'] unless data.nil?
    end

    raise "Failed to determine the last start time for Fiber Analysis parsing run." unless last_run

    start_time = Time.zone.now
    find_and_parse_fiber_contents Time.zone.parse last_run
    # Everything's going to be UTC in here..that's fine
    key.data= {'last_run_time' => start_time.to_s}
    key.save!

    nil
  end

  def self.find_and_parse_fiber_contents updated_since, stop_time = Time.zone.now
    product_ids = base_query.where("custom_values.updated_at >= ?", updated_since)
                    .where("custom_values.updated_at <= ?", stop_time)
                    .pluck("products.id")

    # Reuse the same parser instance to avoid having to reload 47 custom definitions for each product we parse a definition for
    instance = self.new
    product_ids.each do |id|
      parse_and_set_fiber_content id, instance
    end
  end

  def self.base_query
    fiber_content_def = prep_custom_definitions([:fiber_content])[:fiber_content]
    Product.joins(:custom_values).where("custom_values.custom_definition_id = ? ", fiber_content_def.id)
  end

  def self.update_styles styles
    styles = styles.split /\s*\n\s*/

    product_ids = base_query.where(unique_identifier: styles).pluck("products.id")
    # Reuse the same parser instance to avoid having to reload 47 custom definitions for each product we parse a definition for
    instance = self.new
    product_ids.each do |id|
      parse_and_set_fiber_content id, instance
    end
  end

  def self.parse_and_set_fiber_content product, instance = self.new
    #Allow passing in the product id, so we can use via delayed_job without having to serialize the whole product.
    if product.is_a? Numeric
      product = Product.where(id: product).first
    end

    return nil unless product

    instance.parse_and_set_fiber_content product
  end

  def parse_and_set_fiber_content product
    init_custom_values
    result = nil
    failed = true
    begin
      fiber = product.get_custom_value(@cdefs[:fiber_content]).value
      unless fiber.blank?
        result = parse_fiber_content fiber
      end
      failed = false
      
    rescue FiberParseError => e
      # If there's an actual fiber error, we can get the bad results 
      # and set them into the fiber fields so the user can see how the data was
      # badly parsed.
      result = e.parse_results
    rescue
      # Don't really care, we just don't want to blow out entirely.
      raise e if Rails.env.test?
    end

    # First things, first...make sure the results hash has actually changed values before we bother
    # writing the results into the custom values.
    fingerprint = results_fingerprint result

    xref_fingerprint = DataCrossReference.find_rl_fabric_fingerprint product.unique_identifier

    # If the fingerprints match, don't update anything, just return true as if everything
    # worked without issue.
    return true if fingerprint == xref_fingerprint

    batch_writes = convert_results_to_custom_values product, result, failed
    Lock.with_lock_retry(product) do
      CustomValue.batch_write! batch_writes, false, skip_insert_nil_values: true
      DataCrossReference.create_rl_fabric_fingerprint! product.unique_identifier, fingerprint
    end
    !failed
  end

  def parse_fiber_content fiber
    footwear = footwear? fiber

    if footwear
      results = parse_footwear fiber
    else
      results = non_footwear_parse fiber
    end
    results.delete :algorithm if results

    # invalid_results? raises errors if anything is bad, so by virtue
    # of it not blowing up, we have a valid fiber content
    invalid_results?(results, true)

    results
  end

  class FiberParseError < StandardError
    attr_accessor :parse_results
  end

  private
    def init_custom_values
      # Shortcut to avoid typing out 45 custom def fields here
      if @cdefs.nil?
        cdefs = []
        (1..15).each do |x|
          cdefs << "fabric_type_#{x}".to_sym
          cdefs << "fabric_#{x}".to_sym
          cdefs << "fabric_percent_#{x}".to_sym
        end
        cdefs << :fiber_content
        cdefs << :msl_fiber_failure
        @cdefs = self.class.prep_custom_definitions cdefs
      end

      @cdefs
    end

    def non_footwear_parse fiber
      # We're converting newlines (etc) into non-printing ASCII char 30 (record separator)
      # so that we can parse across lines easier where needed, but we then have a single char to
      # look for if we need to not parse across lines later on (.ie when parsing single fiber components out of a longer list)
      fiber = fiber.split(/\r?\n/).select {|l| !l.blank?}.join(30.chr)

      # Check if there is any colons (indicating multiple fiber components) in the 
      # description and split the fabric apart based on it
      split_fiber = fiber.split /\s*\w+\s*[:]\s*/

      if split_fiber.length == 1
        # No components found..just do a simple pass
        results = single_line_nonfootwear fiber
      else
        (0..(split_fiber.length - 1)).each do |x|
          next if x.blank?

          # Skip the split fiber index unless it has a numeric value in here that looks like it could be a percentage.
          # We're requiring the usage of decimal + % on these multi-component ones
          if split_fiber[x] =~ /(?:((?:\d{1,2}\.\d+)|(?:\d{1,3}))\s*%)|(?:%\s*((?:\d{1,2}\.\d+)|(?:\d{1,3})))/
            results = single_line_nonfootwear split_fiber[x]
            break
          end
        end
      end
      

      results
    end

    def parse_footwear fiber
      # Footwear doesn't generally have multiple lines, and when it does, it's not there for any reason
      fiber = fiber.split(/\r?\n/).join " "

      # In general, the footwear fiber is either like this
      # FIBER UPPER / FIBER (OUT)SOLE
      #   OR
      # UPPER: Fiber (OUT)SOLE: Fiber
      if fiber =~ /up{1,3}ers?\s*[[:punct:]]\s*(.*?)(?:out)?soles?\s*[[:punct:]]\s*(.*)/i
        results = footwear_leading_components fiber
      elsif fiber =~ /up{1,3}ers?\s*[,;\/ \d].+(?:out)?sole/i
        results = footwear_trailing_components fiber
      end

      results[:algorithm] = "footwear" if results

      results
    end

    def single_line_nonfootwear fiber
      # What we're looking for here is essentially one or more of the following
      # X% Fabric
      # or 
      # X% Fabric Y% Fabric
      # or
      # Fabric
      results = {}
      parse_standard_fiber_string fiber, results
      results[:algorithm] = "single_non_footwear"
      results
    end

    def footwear_trailing_components fiber
      # This should handle cases like the following
      # FIBER UPPER / FIBER (OUT)SOLE
      # 90%cotton+5%lea+5%rubber Uppers / 45.8%rubber+54.2%fabric Outsole
      # Basically, anything where it's Fiber followed by Upper and then an outsole later on.

      # So, find where in the string the Upper(s) is and parse everything prior to that as the primary fabric.
      # Then everything between Upper(s) and (Out)sole is the sole fabric
      results = nil
      md = fiber.match(/up{1,3}ers?\s*/i)
      if md
        upper_fiber = md.pre_match
        sole_fiber = md.post_match
        md = sole_fiber.match(/(?:out)?soles?/i)
        if md
          results = {}
          count = parse_standard_fiber_string strip_punctuation(upper_fiber), results, component_type: "Upper"
          parse_standard_fiber_string strip_punctuation(md.pre_match), results, component_type: "Sole", starting_index: (count + 1)
        end
      end

      results
    end 

    def footwear_leading_components fiber
      # This should handle cases like the following
      # UPPER: FIBER / Sole: Fiber
      # Upper, 90%cotton+5%lea+5%rubber Outsole, 45.8%rubber+54.2%fabric
      # Basically, anything where it's Upper: and then (Out)sole: later on
      if fiber.match /up{1,3}ers?\s*[[:punct:]](.*?)(?:out)?soles?\s*[[:punct:]](.*)/i
        # We can just use the two match groups above to extract the fiber details
        results = {}
        count = parse_standard_fiber_string $1, results, component_type: "Upper"
        parse_standard_fiber_string $2, results, component_type: "Sole", starting_index: (count + 1)
      end

      results
    end

    def parse_standard_fiber_string fiber, results, starting_index: 1, component_type: "Outer", fiber_split_check: true

      local_results = {}
      values_parsed = 0

      if fiber_split_check && (count = parse_numeric_fiber_split(fiber, results, starting_index, component_type))
        values_parsed = count
      elsif (found = fiber.scan /((?:(?:\d{1,2}\.\d+)|(?:\d{1,3}))\s*%?\s*)([^0-9%\x1E,:;]+)/).size > 0
        # The \x1E used above is the non-printing char we added above to represent newlines

        # If any of the numeric groups included a percent, we want to skip any numeric grouping that 
        # then doesn't have one.
        require_percent = found.map {|v| v[0]}.select {|v| v.include? "%"}.size > 0
        counter = (starting_index - 1)
        (0..(found.length-1)).each do |n|
          percentage = found[n][0]
          if !require_percent || percentage.include?("%")
            counter += 1
            local_results["percent_#{counter}".to_sym] = percentage.gsub(/\s*%\s*/, "").strip
            local_results["fiber_#{counter}".to_sym] = cleanup_fiber found[n][1]
            local_results["type_#{counter}".to_sym] = component_type
          end
        end

        values_parsed = counter - (starting_index - 1)
      elsif (found = fiber.scan /^[^%\d]+$/).size > 0
        # Missing % and numbers alltogether, means we've just got a fabric and we'll assume 100% of that fabric
        local_results["percent_#{starting_index}".to_sym] = "100"

        # Only use everything up to the first bit of puncation that might be used for conjoining different
        # components
        # This is primarily useful for cases where we have something like
        # 'Teak wood, Saddle Leather (RL Standard), Natural Leather, Polished Nickel hardware, Saddle Poly Suede'
        # Which should evaluate to "Teak wood" as the fiber (RL lists in order of percentage make-up in these cases
        # or, at least that's how they've said they do)
        # The \x1E is the non-printing char we added above to represent newlines
        fiber = (fiber =~ /(.*?)[,\/+|&\x1E]/ ? $1 : fiber)

        local_results["fiber_#{starting_index}".to_sym] = cleanup_fiber fiber
        local_results["type_#{starting_index}".to_sym] = component_type

        values_parsed = 1
      end

      if values_parsed > 0
        results.merge! local_results
      end

      values_parsed
    end

    def parse_numeric_fiber_split fiber, results, starting_index, component_type
      # This determines if we have a fiber that looks like 
      # 90%/10 Fiber1 / Fiber 2

      split_fiber = fiber.split("/")
      return nil if split_fiber.size < 3

      # Make sure the first X components are numeric (the last will also have a fiber in it)
      # Then make sure there are the same # of fabric compnents as numeric components
      numerics = []
      fabrics = []
      split_fiber.each do |f|
        # If we found a what we think is a fabric component, then don't bother
        # to even look for numeric components since they need to all trail numerics

        # This basically just matches the start of the line having an int or double 
        # either pro/pre-ceeded by a %
        if fabrics.length == 0 && f.strip =~ /^*%?\s*((?:\d{1,2}\.\d+)|(?:\d{1,3}))\s*%?\s*/
          # Store off the numeric value
          numerics << $1

          # See if there's anything after the numeric match that may be fabric.
          # Basically, if there's anything that's alphabetical after the numeric we pulled,
          # we'll consider it a fabric.
          post_match =  $~.post_match
          fabrics << post_match if post_match =~ /[a-zA-Z]/
        elsif fabrics.length > 0 && !f.blank?
          # Just consider every piece once we're past the numerics as 
          # fabric content
          fabrics << f.strip
        end
      end

      if numerics.size != fabrics.size
        return nil
      else
        # We can really just re-assemble the fiber components into easy to parse components and pass them back through
        # the standard parse methods
        reconstituted_fabric = ""
        numerics.each_with_index do |num, x|
          reconstituted_fabric << "#{num} #{fabrics[x]}"
          reconstituted_fabric << " / " if (x + 1) < numerics.length
        end

        return parse_standard_fiber_string reconstituted_fabric, results, starting_index: starting_index, component_type: component_type, fiber_split_check: false
      end
    end

    def cleanup_fiber fiber
      # Remove our newline stand-ins (and anything after them, fabrics shouldn't wrap past end of lines)
      fiber = fiber.gsub /\x1E.*/, ""

      # We're going to do two passes on the xref lookups here...the raw fiber value passed in
      # and then later on the cleaned up one.  This is primarily because we want to give RL the chance
      # to provide substitutions on the values they see in the descriptions and then also on the
      # values the cleanup turns them into.
      xref = xref_value fiber
      return xref unless xref.blank?

      # Strip out a series of comments we don't need along w/ the word boundaries
      ["est\.", "est", "estimated"].each do |com|
        fiber = fiber.gsub(/\b#{com}\b/i, "")
      end
      xref = xref_value fiber
      return xref unless xref.blank?

      # Strip anything that comes after w/, with, and, /, ' - ', more than 3 spaces
      fiber = fiber.gsub /(?:\bw\/|\bwith|\bw\b|\band|\bon|&|\/|\(|\+|\s+-+\s+|\s{3,}).*$/i, ""
      xref = xref_value fiber
      return xref unless xref.blank?

      # Strip out anything like "(Exclusive Of X)" - parenths or quotes optional
      fiber = fiber.gsub /[\('"]?\b+exclusive of \w+\b[\)'"]?/i, ""
      xref = xref_value fiber
      return xref unless xref.blank?

      fiber = strip_punctuation fiber
      xref = xref_value fiber
      return xref unless xref.blank?
  
      xref = xref_value fiber
      xref.blank? ? fiber : xref
    end

    def strip_punctuation s
      # Strip any trailing whitespace and/or punctuation.
      s = s[0..-2] while s =~ /[[[:punct:]]\s=`~$^+|<>]$/

      # Strip any leading whitespace and/or punctuation
      s = s[1..-1] while s =~ /^[[[:punct:]]\s=`~$^+|<>]/

      s
    end

    def footwear? fiber_content
      # 99% of footwear matches this expression having both upper and sole in the fiber content
      # Common spelling mistake is 1 or 3 p's in upper - might as well support it
      fiber_content =~ /\bup{1,}ers?(?:\b|\d)/i && fiber_content =~ /\b(?:(?:soles?)|(?:outsoles?))\b/i
    end

    def invalid_results? results, strip_overages = false
      raise error("Failed to find fabric content and percentages for all discovered components.", results) if results.nil? || results.size == 0

      # What we're looking for are the following
      # 1) Each set of results (fiber_X, type_X, percent_x) has values in each field
      # 2) The percentage of each type of fiber adds up to 100 (or a mulitiple of 100, since
      # in certain cases we'll parse out multiples of 100% but then only return the first 100%)
      percentages = {}
      valid_fibers = all_validated_fabrics

      (1..15).each do |x|
        fiber, type, percent = all_fiber_fields results, x

        # Returns a missing descriptor error if one of the 3 values is blank and one of the other 2 isn't.
        all_blank = "#{fiber}#{type}#{percent}".blank?
        next if all_blank

        raise error("Failed to find fabric content and percentages for all discovered components.", results) if (fiber.blank? || type.blank? || percent.blank?)

        percentages[type] ||= []
        p = percent.to_f
        raise error("Invalid percentage value '#{p}' found.  Percentages must be greater than 0 and less than or equal to 100.", results) if p <= 0

        percentages[type] << p
      end

      percentages.keys.each do |key|
        total = percentages[key].inject(:+)
        raise error("Fabric percentages must add up to 100%.", results) if (total % 100) > 0
      end

      if strip_overages
        strip_component_overages results
      end

      # Only validate the fibers after we've stripped the overages.
      (1..15).each do |x|
        fiber, *ignore = all_fiber_fields results, x
        raise error("Invalid fabric '#{fiber}' found.", results) unless fiber.blank? || valid_fabric?(fiber)
      end

      nil
    end

    def error msg, results
      e = FiberParseError.new msg
      e.parse_results = results
      e
    end

    def strip_component_overages results
      percentages = {}
      (1..15).each do |x|
        fiber, type, percent = all_fiber_fields results, x
        percentages[type] ||= 0
        if percentages[type] >= 100
          results.delete "type_#{x}".to_sym
          results.delete "percent_#{x}".to_sym
          results.delete "fiber_#{x}".to_sym
        else
          percentages[type] += percent.to_f
        end
      end
    end

    def all_fiber_fields results, index
      [results["fiber_#{index}".to_sym], results["type_#{index}".to_sym], results["percent_#{index}".to_sym]]
    end

    def convert_results_to_custom_values product, results, parse_failed
      cv = []
      # Results will be nil if the process blew up (exceptionally), overwrite everything in this
      # case (don't leave stale fields behind, it's confusing).  The old fields will be listed in the history
      # if anyone needs to see them
      results = {} unless results

      (1..15).each do |x|
        fiber, type, percent = all_fiber_fields results, x
        cv << get_or_create_cv(product, "fabric_type_#{x}".to_sym, type)
        cv << get_or_create_cv(product, "fabric_#{x}".to_sym, fiber)
        cv << get_or_create_cv(product, "fabric_percent_#{x}".to_sym, percent)
      end

      cv << get_or_create_cv(product, :msl_fiber_failure, parse_failed)

      cv
    end

    def get_or_create_cv product, cv_sym, value
      cv = product.get_custom_value @cdefs[cv_sym]
      cv.value = value

      cv
    end

    def xref_value fabric
      unless @all_xrefs
        pairs = DataCrossReference.get_all_pairs(DataCrossReference::RL_FABRIC_XREF)
        # Now downcase every key, so we retain the case insenstive matching that a straight db lookup would give us
        @all_xrefs = {}
        pairs.map {|k, v| @all_xrefs[k.downcase] = v}
      end

      @all_xrefs[fabric.downcase]
    end

    def valid_fabric? fabric
      all_validated_fabrics.include? fabric.to_s.downcase
    end

    def all_validated_fabrics
      unless @all_fabrics
        # We want any case of the Fabric to be acceptable.
        @all_fabrics = Set.new(DataCrossReference.get_all_pairs(DataCrossReference::RL_VALIDATED_FABRIC).keys.map(&:downcase))
      end

      @all_fabrics
    end

    def results_fingerprint results
      values = []
      (1..15).each do |x|
        fiber, type, percent = all_fiber_fields results, x
        values << results["type_#{x}".to_sym].to_s
        values << results["fiber_#{x}".to_sym].to_s
        values << results["percent_#{x}".to_sym].to_s
      end

      # Really the only reason I'm hashing this is to ensure a constant width field, otherwise it's possible
      # concat'ing the result data together it'll overflow the 255 char width (possible, though not likely).
      Digest::MD5.hexdigest values.join("\n")
    end

end; end; end; end;
