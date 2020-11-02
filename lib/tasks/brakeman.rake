namespace :brakeman do
  desc "Runs a full brakeman scan using config file in .brakeman/brakeman.yml."
  task scan: :environment do
    sh 'brakeman -c .brakeman/brakeman.yml'
  end

  desc "Runs a brakeman scan with the intent of updating the ignore files, using the config file in .brakeman/brakeman.yml."
  task ignore: :environment do
    sh 'brakeman -I -c .brakeman/brakeman.yml'
  end

end

# This allows you to do `rake rubocop` to run a scan (instead of `rake rubocop:scan`)
task brakeman: ["brakeman:scan"]
