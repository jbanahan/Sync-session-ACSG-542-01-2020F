module OpenChain; class LoadEnvironment

  def self.load
    load_dotenv_files
    include_escape_yaml_patch
    nil
  end

  def self.application_load
    # Because it relies on Rails secrets for configuration, memcache can't be loaded until secrets are available to
    # be utilized, which is after the Rails::Application block is opened.

    # There's a couple times when setting up where the config files may not exist (or have values), such
    # as when configuring a brand new instance.  Setting up memcache as early in the process as we do
    # then will cause those tasks to fail, so don't do that.  These tasks should all run without the rake "environment"
    # tag thus it will not load any initializers, etc.

    # At the time this method is called, MasterSetup doesn't exist, so we use ENV directly, rather than MasterSetup.env
    setup_memcache unless ENV["WITHOUT_CONFIG_FILES"].to_s.downcase == "true"
    nil
  end

  # Downloads all configuration files from S3 bucket.
  # Uses ENV var "CONFIGURATION_BUCKET" or configuration_bucket secrets key to determine the bucket to use
  # Uses ENV var "CONFIGURATION_NAMESPACE" and falls back to secrets host key and then MasterSetup.instance_identifier
  # to determine what configuration namespace (prefix) to use to determine which instance's data to download.
  #
  # * print_output - If true (defaults to false), will print out which files are being downloaded.  This is primarily
  #   just for use via the Rake task that utilizes this method.
  def self.download_config_files print_output: false
    bucket = configuration_bucket
    namespace = configuration_namespace

    raise "No configuration bucket found. Set a configuration_bucket key in secrets.yml or set the CONFIGURATION_BUCKET env var." if bucket.blank?

    OpenChain::S3.each_file_in_bucket(bucket, prefix: "#{namespace}/") do |key|
      download_file(MasterSetup.instance_directory, namespace, bucket, key, print_output)
    end
  end

  # Returns true if run from `rails c[onsole]` or a `rake` task
  def self.running_from_console?
    # At the moment, any time rake is invoked it means we're running from the command line
    # We're not starting a server via rake
    # This may need to change if we upgrade to newer versions of rails that unify rails/rake commands
    (Rails.const_defined?("Console") || File.basename($PROGRAM_NAME) == "rake")
  end

  def self.configuration_bucket
    MasterSetup.env("CONFIGURATION_BUCKET").presence || MasterSetup.secrets["configuration_bucket"]
  end

  def self.configuration_namespace
    # I'm intentially leaving out MasterSetup.instance_identifier because it comes from a user settable value on the master setups screen
    # and I don't want it used in the rake command that will be built from this
    MasterSetup.env("CONFIGURATION_NAMESPACE").presence || MasterSetup.secrets["configuration_namespace"].presence ||
      deployment_host.presence || MasterSetup.instance_directory.basename.to_s
  end

  class << self

    private

      def load_dotenv_files
        # Load environment vars w/ Dotenv
        Dotenv::Railtie.load
      end

      def setup_memcache
        # The actual call to require the cache wrapper file does all the actual setup work
        require_relative 'cache_wrapper'
        CacheWrapper.instance
      end

      def deployment_host
        host = MasterSetup.secrets["host"]
        return nil if host.blank?

        # Extract the "machine name" portion of the URL that should be in the "host" secret's value (.ie everything up to the first period)
        if host =~ /^([^.]+)\./
          Regexp.last_match(1)
        else # rubocop:disable Style/EmptyElse
          nil
        end
      end

      def include_escape_yaml_patch
        # Apply the patch that lets us properly handle yaml values that need to be escaped coming from environment variables
        # I initially tried to patch Kernel directly to allow us to just do something like escape_yaml("String") but
        # I couldn't get that to work for some reason...the method wasn't picked up w/ the .yml files were loaded.
        unless "".respond_to?(:escape_yaml)
          String.include YamlEscapePatch
          # include our patch in nil so that we can do ENV["blargh"].escape_yaml in our .yml files even if the environment variable
          # isn't there
          NilClass.include YamlEscapePatch
        end
      end

      def download_file rails_root, namespace, bucket, s3_path, print_output
        # Strip the namespace prefix from path
        if s3_path.starts_with?("#{namespace}/")
          output_path = s3_path[(namespace.length + 1)..-1]
        else
          output_path = s3_path
        end

        if print_output
          puts "Downloading #{output_path} from s3://#{bucket}" # rubocop:disable Rails/Output
        end

        io = StringIO.new
        OpenChain::S3.get_data(bucket, s3_path, io)
        io.rewind

        # Create the file's parent dir if required...this really shouldn't be required
        # but it's possible in cases where we're setting up a new deployment
        output_file = rails_root.join(output_path)
        output_dir = output_file.parent
        output_dir.mkpath if !output_dir.exist?

        File.open(output_file, "w") do |file|
          file << io.read
        end

        nil
      rescue OpenChain::S3::NoSuchKeyError
        # We don't care about this...just skip the file
      end
  end

  module YamlEscapePatch
    # This patch exists solely so that we can safely do things like the following in a yaml file
    #
    # key: <%= ENV["VALUE"].escape_yaml %>
    #
    # If we don't do this and ENV["VALUE"] has some special characters that need to be escaped in yaml then
    # the application will crash because actual yaml data will be unproperly formatted.
    #
    # To prevent this, we're using YAML's dump_stream method which does this for us with some slight parsing
    # of the output.
    def escape_yaml
      return self if self.blank?

      escaped_string = YAML.dump_stream self
      # At this point our escaped_string will should look like this:
      # --- string_value\n...\n
      if escaped_string =~ /--- (.+)\n(?:...\n)?/
        Regexp.last_match(1)
      else
        # If the dumped/escaped string isn't what we're expecting...just return the underlying string
        self
      end
    end
  end

end; end
