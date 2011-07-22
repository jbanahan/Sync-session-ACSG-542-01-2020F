require 'open3'

class Upgrade

  def self.upgrade target
    get_source target
    apply_upgrade
  end

private
  def self.get_source target
    puts "Fetching source"
    stdout, stderr, status = Open3.capture3 'git fetch'
    raise "git fetch failed: #{stderr}" unless status.success?
    puts "Source fetched, checking out #{target}"
    stdout, stderr, status = Open3.capture3 "git checkout #{target}"
    raise "git checkout failed: #{stderr}" unless status.success?
    puts "Source checked out"
  end

  def self.apply_upgrade
    puts "Touching stop.txt"
    `touch tmp/stop.txt`
    puts "Stopping Delayed Job"
    DelayedJobManager.stop
    raise "Delayed job should be stopped and is still running." if DelayedJobManager.running?
    puts "Delayed Job stopped, running bundle install"
    stdout, stderr, status = Open3.capture3 "bundle install"
    raise "Bundle install failed: #{stderr}" unless status.success?
    puts "Bundle complete, running migrations"
    stdout, stderr, status = Open3.capture3 "rake db:migrate"
    puts stdout
    raise "Migration failed: #{stderr}" unless status.success?
    puts "Migration complete"
    puts "Touching restart.txt"
    `touch tmp/restart.txt`
    puts "Upgrade complete"
  end

end
