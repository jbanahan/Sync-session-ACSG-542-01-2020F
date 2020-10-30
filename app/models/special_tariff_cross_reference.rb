# == Schema Information
#
# Table name: special_tariff_cross_references
#
#  country_origin_iso   :string(255)
#  created_at           :datetime         not null
#  effective_date_end   :date
#  effective_date_start :date
#  hts_number           :string(255)
#  id                   :integer          not null, primary key
#  import_country_iso   :string(255)
#  priority             :integer
#  special_hts_number   :string(255)
#  special_tariff_type  :string(255)
#  suppress_from_feeds  :boolean          default(FALSE)
#  updated_at           :datetime         not null
#
# Indexes
#
#  by_import_country_effective_date_country_origin_tariff_type      (import_country_iso,effective_date_start,country_origin_iso,special_tariff_type)
#  hts_date_index                                                   (special_hts_number,effective_date_start,effective_date_end)
#  index_special_tariff_cross_references_on_hts_country_start_date  (hts_number,country_origin_iso,effective_date_start)
#

class SpecialTariffCrossReference < ActiveRecord::Base
  before_validation :clean_hts
  before_validation :clean_country

  # Finds all special tariffs applicable for the parameters given.
  # The method returns a SpecialTariffHashResult object, which has basically a single method named tariff_for(country, hts) which is
  # used to find all the applicable special tariff objects for the given country of origin / hts combination.
  #
  # import_country_iso - the country the goods are being imported into - .ie the country enacting the tariffs
  # is_parts_feed - If true, any tariffs that should not be auto added to feeds to external systems will be ignored.
  # reference_date - The date to base the effective date calculations off of, defaults to the current time
  # country_origin_is - if you want to limit to only a specific country of origin.
  # special_tariff_types - if you want to limit the results to only specific types
  # use_special_number_as_key - if you want to key the results by the special number (.ie find if a number is a special number), then pass true (default = false)
  def self.find_special_tariff_hash(import_country_iso, is_parts_feed, reference_date: Time.zone.now.to_date,
                                    country_origin_iso: nil, special_tariff_types: nil, use_special_number_as_key: false)

    query = SpecialTariffCrossReference.where(import_country_iso: import_country_iso)
    # If the parameter indicate a parts feed, then don't include the suppressed values.
    query = query.where(suppress_from_feeds: false) if is_parts_feed == true

    if reference_date
      query = query.where("effective_date_start <= ? OR effective_date_start IS NULL", reference_date)
      query = query.where("effective_date_end > ? OR effective_date_end IS NULL", reference_date)
    end

    if country_origin_iso
      query = query.where("country_origin_iso IS NULL OR country_origin_iso in (?)", Array.wrap(country_origin_iso))
    end

    if special_tariff_types.present?
      query = query.where("special_tariff_type IN (?)", Array.wrap(special_tariff_types))
    end

    result = SpecialTariffHashResult.new
    query.order([:priority, :created_at]).each do |record|
     result.insert record, use_special_number_as_key: use_special_number_as_key
    end

    result
  end

  # This is primarily meant to be run from the console to load csv tariff files formatted like
  # program type, import country iso, hts, special hts, country of origin iso (can be blank if tariff is for any coo),
  # start date, end date (optional), priority (optional), suppress from feeds (optional)
  def self.parse io, opts = {}
    CSV.parse(io, (opts[:csv_opts].presence || {})) do |row|
      special_tariff_type = (row[0].to_s.strip.presence || nil)
      next if special_tariff_type.blank?

      import_country_iso = row[1].to_s.strip.upcase
      next if import_country_iso.blank?

      hts_number = row[2].to_s.gsub(".", "")
      special_hts_number = row[3].to_s.gsub(".", "")
      next unless valid_hts_number?(hts_number) && valid_hts_number?(special_hts_number)

      coo = row[4].to_s.strip.presence || nil
      effective_date_start = Time.zone.parse(row[5]).to_date
      effective_date_end = begin
                             Time.zone.parse(row[6]).to_date
                           rescue StandardError
                             nil
                           end

      # Use float parse, since there's no reason not to support someone putting "1.0" which'll make the Integer constructor puke
      priority = begin
                   Float(row[7].to_s.strip).to_i
                 rescue StandardError
                   nil
                 end
      suppress_from_feeds = ["Y", "TRUE", "1"].include?(row[8].to_s.strip.upcase)

      ref = SpecialTariffCrossReference.where(import_country_iso: import_country_iso, hts_number: hts_number,
                                              special_hts_number: special_hts_number, country_origin_iso: coo,
                                              effective_date_start: effective_date_start,
                                              special_tariff_type: special_tariff_type).first_or_initialize
      ref.effective_date_end = effective_date_end
      ref.priority = priority
      ref.suppress_from_feeds = suppress_from_feeds

      ref.save!
    end
  end

  def self.valid_hts_number? hts
    hts.present? && (hts.to_s =~ /\A\d+\z/)
  end
  private_class_method :valid_hts_number?

  class SpecialTariffHashResult
    extend Forwardable

    def_delegators :@results, :clear, :empty?

    def initialize
      @results = {}
    end

    def insert special_tariff, use_special_number_as_key: false
      country = special_tariff.country_origin_iso.to_s.strip.upcase

      @results[country] ||= SpecialTariffHash.new
      @results[country].insert special_tariff, use_special_number_as_key: use_special_number_as_key
    end

    def tariffs_for country_origin_iso, hts_number
      country = country_origin_iso.to_s.strip.upcase

      if country.present?
        country_tariffs = @results[country].try(:[], hts_number)
      end

      no_country_tariffs = @results[""].try(:[], hts_number)

      sort_tariffs(Array.wrap(country_tariffs) + Array.wrap(no_country_tariffs))
    end

    def size
      @results.values.map(&:size).sum
    end

    private

      def sort_tariffs values
        values.sort do |a, b|
          # Sort the vals on priority and then fall back to created at
          v = (a.priority.presence || 1_000_000) <=> (b.priority.presence || 1_000_000)

          if v == 0
            v = a.created_at <=> b.created_at
          end

          v
        end
      end
  end

  class SpecialTariffHash
    extend Forwardable

    def_delegators :@hash, :clear, :empty?

    def initialize
      @hash = {}
    end

    def insert special_tariff, use_special_number_as_key: false
      raise IllegalArgumentError, "SpecialTariffHash only supports SpecialTariffCrossReference objects." unless special_tariff.is_a?(SpecialTariffCrossReference)

      tariff_type = special_tariff.special_tariff_type.to_s.strip.upcase
      tariff_type_hash = @hash[tariff_type] ||= {}
      hash_key = (use_special_number_as_key ? special_tariff.special_hts_number : special_tariff.hts_number)
      tariff_type_hash[hash_key] ||= []
      tariff_type_hash[hash_key] << special_tariff

      special_tariff
    end

    def [] hts_number
      values = []
      @hash.each_pair do |_tariff_type, tariffs|
        # We can't mutate the hts_number, otherwise we invalidate the number for other iterations through
        # the each_pair loop
        local_hts = hts_number

        # What we're going to do is take the full number given and then work our way back through the hash such that we find the "best matching"
        # tariff (.ie the one with the most consecutive matching digits)
        found = false
        begin
          val = tariffs[local_hts]
          if val.present?
            values.push(*val)
            found = true
          end
        end while !found && (local_hts = local_hts[0..-2]).try(:length).to_i > 2
      end

      values.presence
    end

    def size
      @hash.values.map {|h| h.values.map(&:size).sum }.sum
    end
  end

  def clean_hts
    if self.hts_number.present?
      self.hts_number = self.hts_number.to_s.gsub(/[^0-9A-Za-z]/, '')
    end

    if self.special_hts_number.present?
      self.special_hts_number = self.special_hts_number.to_s.gsub(/[^0-9A-Za-z]/, '')
    end

    true
  end

  def clean_country
    if self.country_origin_iso.blank?
      self.country_origin_iso = nil
    end

    if self.import_country_iso.blank?
      self.import_country_iso = nil
    end

    true
  end

  def self.find_can_view(user)
    if user.admin?
      SpecialTariffCrossReference.where("1=1")
    else
      SpecialTariffCrossReference.where("1=0")
    end
  end

  class << self
    private

    def can_view? user
      user.admin?
    end

    def can_edit? user
      user.admin?
    end
  end
end
