# The following is required to patch issues related to upgrading to Ruby 2.5.
# Once we're on Rails 4 (perhaps 5) this can likely be removed since they support 2.5 officially.

if RUBY_VERSION =~ /^2\.[456789]/
  if Rails::VERSION::MAJOR == 3

    ### Begin Fixnum deprecation related fixes ####
    module Arel; module Visitors
      class DepthFirst < Arel::Visitors::Visitor
        alias :visit_Integer :terminal
      end

      class Dot < Arel::Visitors::Visitor
        alias :visit_Integer :visit_String
      end

      class ToSql < Arel::Visitors::Visitor
        alias :visit_Integer :literal
      end
    end; end

    # This can be removed potentially in Rails 4, basically whenever the rails code fixes
    # the wait_timeout line below to check for Integer, rather than Fixnum
    module ActiveRecord; module ConnectionAdapters; class Mysql2Adapter < ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter

      private 
        def configure_connection
          @connection.query_options.merge!(:as => :array)

          # By default, MySQL 'where id is null' selects the last inserted id.
          # Turn this off. http://dev.rubyonrails.org/ticket/6778
          variable_assignments = ['SQL_AUTO_IS_NULL=0']
          encoding = @config[:encoding]

          # make sure we set the encoding
          variable_assignments << "NAMES '#{encoding}'" if encoding

          # increase timeout so mysql server doesn't disconnect us
          wait_timeout = @config[:wait_timeout]
          wait_timeout = 2147483 unless wait_timeout.is_a?(Integer)
          variable_assignments << "@@wait_timeout = #{wait_timeout}"

          execute("SET #{variable_assignments.join(', ')}", :skip_logging)
        end

    end; end; end

    module ActiveRecord; module ConnectionAdapters; class Column

      def klass
        case type
        when :integer                     then Integer
        when :float                       then Float
        when :decimal                     then BigDecimal
        when :datetime, :timestamp, :time then Time
        when :date                        then Date
        when :text, :string, :binary      then String
        when :boolean                     then Object
        end
      end

    end; end; end;

    module ActiveRecord; module ConnectionAdapters; class AbstractMysqlAdapter < ActiveRecord::ConnectionAdapters::AbstractAdapter
      protected 
        def add_index_length(option_strings, column_names, options = {})
          if options.is_a?(Hash) && length = options[:length]
            case length
            when Hash
              column_names.each {|name| option_strings[name] += "(#{length[name]})" if length.has_key?(name) && length[name].present?}
            when Integer
              column_names.each {|name| option_strings[name] += "(#{length})"}
            end
          end

          return option_strings
        end
    end; end; end


    module ActiveRecord; module Associations; class CollectionAssociation < ActiveRecord::Associations::Association

      def destroy(*records)
        records = find(records) if records.any? { |record| record.kind_of?(Integer) || record.kind_of?(String) }
        delete_or_destroy(records, :destroy)
      end

    end; end; end;


    module Mail; class AttachmentsList < Array
      
      def [](index_value)
        if index_value.is_a?(Integer)
          self.fetch(index_value)
        else
          self.select { |a| a.filename == index_value }.first
        end
      end

    end; end

    # This fixes an issue where the integer type (what was Fixnum) is not 
    # recognized when generating XML and the type attribute is generated as 
    # "Integer" rather than "integer"
    ActiveSupport::XmlMini::TYPE_NAMES["Integer"] = "integer"

    module Mail; module Multibyte; class Chars
      def []=(*args)
        replace_by = args.pop
        # Indexed replace with regular expressions already works
        if args.first.is_a?(Regexp)
          @wrapped_string[*args] = replace_by
        else
          result = Unicode.u_unpack(@wrapped_string)
          if args[0].is_a?(Integer)
            raise IndexError, "index #{args[0]} out of string" if args[0] >= result.length
            min = args[0]
            max = args[1].nil? ? min : (min + args[1] - 1)
            range = Range.new(min, max)
            replace_by = [replace_by].pack('U') if replace_by.is_a?(Integer)
          elsif args.first.is_a?(Range)
            raise RangeError, "#{args[0]} out of range" if args[0].min >= result.length
            range = args[0]
          else
            needle = args[0].to_s
            min = index(needle)
            max = min + Unicode.u_unpack(needle).length - 1
            range = Range.new(min, max)
          end
          result[range] = Unicode.u_unpack(replace_by)
          @wrapped_string.replace(result.pack('U*'))
        end
      end
    end; end; end

    module ActiveSupport; module Multibyte; class Chars
      def []=(*args)
        replace_by = args.pop
        # Indexed replace with regular expressions already works
        if args.first.is_a?(Regexp)
          @wrapped_string[*args] = replace_by
        else
          result = Unicode.u_unpack(@wrapped_string)
          case args.first
          when Integer
            raise IndexError, "index #{args[0]} out of string" if args[0] >= result.length
            min = args[0]
            max = args[1].nil? ? min : (min + args[1] - 1)
            range = Range.new(min, max)
            replace_by = [replace_by].pack('U') if replace_by.is_a?(Integer)
          when Range
            raise RangeError, "#{args[0]} out of range" if args[0].min >= result.length
            range = args[0]
          else
            needle = args[0].to_s
            min = index(needle)
            max = min + Unicode.u_unpack(needle).length - 1
            range = Range.new(min, max)
          end
          result[range] = Unicode.u_unpack(replace_by)
          @wrapped_string.replace(result.pack('U*'))
        end
      end
    end; end; end

    module ActionController; module Caching;  module Pages

      def caches_page(*actions)
        return unless perform_caching
        options = actions.extract_options!

        gzip_level = options.fetch(:gzip, page_cache_compression)
        gzip_level = case gzip_level
        when Symbol
          Zlib.const_get(gzip_level.to_s.upcase)
        when Integer
          gzip_level
        when false
          nil
        else
          Zlib::BEST_COMPRESSION
        end

        after_filter({:only => actions}.merge(options)) do |c|
          c.cache_page(nil, nil, gzip_level)
        end
      end

    end; end; end

    #### END FIXNUM RELATED MONKEY PATCHES ####
  else
    raise "Re-evaluate all Ruby 2.5 patches above for Rails versions > 3."
  end

  ## This Monkey Patches BigDecimal to restore how it worked prior to Ruby 2.4 
  ## There's too many spots in our code at the moment that need fixing and other gems 
  ## that are not updated for 2.4 behavior (rails specifically) that I don't want to deal
  ## with the ArgumentError it raises for something like BigDecimal("notanumber"), rather than returning "0".

  class BigDecimal < Numeric
    alias :old_initialize :initialize

    def initialize digits, *args
      begin
        old_initialize(digits, *args)
      rescue ArgumentError => e
        raise e unless e.message =~ /invalid value for BigDecimal\(\)/
        old_initialize("0", *args)
      end
    end
  end

  module Kernel
    def BigDecimal *args
      BigDecimal.new(*args)
    end
  end

  ### End BigDecimal patch ###
end