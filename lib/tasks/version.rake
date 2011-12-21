namespace :oc do
  require(File.join(::Rails.root.to_s, 'lib', 'open_chain', 'central_data'))

  desc 'Create new version with number version_number and password'
  task :create_version, [:version_number, :password] => [:environment] do |t, args|
    version = OpenChain::CentralData::Version.create! args.version_number, args.password
    if version
      puts "Version #{args.version_number} successfully created"
    else
      puts "Version has not been created"
    end
  end
end
