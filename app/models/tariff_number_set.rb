# This is a simple Set extension that can be used to collect tariff number prefixes and then test
# full length tariff numbers against those prefixes to determine if the full length tariff number
# belongs to one of the prefixes.
# 
# Example:
# set = TariffNumberSet.new ["6200"]
# set.include?("6200.12.3456") -> true
#
# Be aware, since this class overrides the include? method, there are several Set arithmetic methods
# that may not function exactly how you might expect. See methods like superset?, subset?, intersect?, disjoint?
class TariffNumberSet < Set

  # This is so we can get at the real include? method from other internal methods
  alias :__include? :include?

  def include? tariff_number
    !internal_lookup(tariff_number).nil?
  end

  # Returns the actual tariff number value in the set the tariff number matches to.
  # The most specific tariff number matched is returned.
  def find tariff_number
    internal_lookup(tariff_number)
  end

  def add tariff_number
    validate_add tariff_number

    super(clean_tariff_number(tariff_number))
  end

  def add? tariff_number
    tariff_number = clean_tariff_number(tariff_number)
    add(tariff_number) unless __include?(tariff_number)
  end

  def delete tariff_number
    tariff_number = clean_tariff_number(tariff_number)
    super(tariff_number)
  end

  def delete? tariff_number
    tariff_number = clean_tariff_number(tariff_number)
    delete(tariff_number) if __include?(tariff_number)
  end

  private
    def clean_tariff_number tariff_number
      TariffRecord.clean_hts tariff_number
    end

    def validate_add tariff_number
      raise ArgumentError, "Tariff Number cannot be nil." if tariff_number.nil?
      raise ArgumentError, "Invalid Tariff Number '#{tariff_number}'." unless TariffRecord.validate_hts(tariff_number)

      true
    end

    def internal_lookup tariff_number
      return nil if tariff_number.nil? || size == 0

      tariff_number = clean_tariff_number(tariff_number)

      found = nil
      while !found && tariff_number.length >= 2
        found = __include?(tariff_number)
        if !found
          tariff_number = tariff_number[0..-2]
        else 
          return tariff_number
        end
      end

      return nil
    end
end