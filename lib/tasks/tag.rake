require_relative 'rake_support'

class TagTasks
  include OpenChain::RakeSupport
  include Rake::DSL

  def initialize
    namespace :tag do
      desc "Automatically determine and apply next release tag to use for OpenChain"
      task :auto do 
        auto_tag()
      end

      desc "Manually determine and apply next release tag to use for OpenChain"
      task :manual do
        manual_tag()
      end

      task :default => ["auto"]
    end
  end

  private
    def do_tag tag_to_use
      success, * = run_command(["git", "tag", tag_to_use], print_output: true)
      exit(1) unless success

      success, * = run_command("git push --tags", print_output: true)
      exit(1) unless success
      puts "Tagged this repository with '#{tag_to_use}' and pushed to remote."
    end

    def auto_tag
      check_for_outdated_branch()

      completed, git_describe, stderr = run_command("git describe --tags")
      if !completed
        puts stderr
        exit 1
      end
      if git_describe =~ /\A(.*)-(\d+)-([a-z0-9]+)\z/
        existing_tag = $1
        if existing_tag =~ /\A(.+)\.(\d+)\z/
          new_tag = "#{$1}.#{$2.to_i + 1}"
          response = get_user_response("Found existing tag #{existing_tag}, would you like to tag this branch with #{new_tag}? ", default_value: "Y")
          tag_to_use = nil
          if response == "Y"
            tag_to_use = new_tag
          else
            accepted = false
            while (!accepted) do
              tag_to_use = get_user_response("Enter tag name", input_test: lambda {|v| v.blank? ? "You must enter a tag." : nil })
              accepted = get_user_response("Are you sure you want to tag the branch with '#{tag_to_use}'? ", default_value: "Y") == "Y"
            end
          end

          do_tag(tag_to_use)
        else
          puts "Found existing tag #{existing_tag}, but it does not appear to follow standard VFI Track tagging patterns.  Cannot auto-increment, please manually tag."
          exit 1
        end
        
      else
        puts "You don't appear to have added any commits since the last tag."
        exit 1
      end
    end

    def manual_tag
      check_for_outdated_branch()

      tag_to_use = get_user_response("Enter tag name", input_test: lambda {|v| v.blank? ? "You must enter a tag." : nil })
      do_tag(tag_to_use)
    end

    def check_for_outdated_branch
      success, stdout, stderr = run_command(["git", "remote", "update"], print_output: false)
      exit(1) unless success

      success, stdout, stderr = run_command(["git", "status"], print_output: false)
      exit(1) unless success

      if stdout =~ /Your branch is behind '(.+)' by (\d+) commits/i
        response = get_user_response("Your branch appears to be behind the origin branch '#{$1}' by #{$2} commits. Shall I update this branch? ", default_value: "Y")
        if response == "Y"
          success, stdout, stderr = run_command(["git", "pull"], print_output: false)
          exit(1) unless success
        else
          puts "You must update this branch manually before proceeding to tag it."
          exit(1)
        end
      end
      
    end
end

# Instantiate the class to define the tasks:
TagTasks.new

# This makes it possible to run the tag:auto task as the default task for the tag namespace -> `rake tag` is the equivalent of `rake tag:auto`
task tag: ["tag:auto"]