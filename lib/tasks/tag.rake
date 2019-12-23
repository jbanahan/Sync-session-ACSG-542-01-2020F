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
    def do_tag branch_name, tag_to_use
      run(["git", "tag", tag_to_use])
      run("git push --tags")
      puts "Tagged #{branch_name} branch with '#{tag_to_use}' and pushed tag to upstream."
    end

    def auto_tag
      branch_name = current_git_branch()
      check_for_outdated_branch(branch_name)
      
      git_describe = run("git describe --tags")

      last_tag, next_tag = get_tag_data branch_name

      # If last tag is missing, it means there were no commit since the last tag
      if last_tag.present?
        tag_to_use = nil

        if next_tag.present?
          response = get_user_response("Found existing tag #{last_tag}, would you like to tag #{branch_name} with #{next_tag}? ", default_value: "Y")
          tag_to_use = nil
          if response == "Y"
            tag_to_use = next_tag  
          end
        end

        tag_to_use = get_user_tag(branch_name) unless tag_to_use.present?
        do_tag(branch_name, tag_to_use) unless tag_to_use.blank?

      else
        puts "You don't appear to have added any commits adding to #{branch_name} since the last tag was added."
        exit 1
      end
    end

    def manual_tag
      branch_name = current_git_branch()
      check_for_outdated_branch(branch_name)

      tag_to_use = get_user_response("Enter tag name", input_test: lambda {|v| v.blank? ? "You must enter a tag." : nil })
      do_tag(branch_name, tag_to_use)
    end

    def check_for_outdated_branch branch
      run(["git", "remote", "update"])
      stdout = run(["git", "status"])

      if stdout =~ /Your branch is behind '(.+)' by (\d+) commits/i
        response = get_user_response("Your #{branch} branch appears to be behind the origin branch '#{$1}' by #{$2} commits. Shall I update this branch? ", default_value: "Y")
        if response == "Y"
          run(["git", "pull"])
        else
          puts "You must update this branch manually before proceeding to tag it."
          exit(1)
        end
      end
    end

    def current_git_branch
      stdout = run(["git", "rev-parse", "--abbrev-ref", "HEAD"])

      stdout.to_s.strip
    end

    # Determines the previous tag and if there have been any commits on this branch since the last tag
    def get_tag_data branch_name
      git_describe = run("git describe --tags")

      last_tag = nil
      next_tag_number = nil

      if git_describe =~ /\A(.*)-(\d+)-([a-z0-9]+)\z/
        last_tag = $1

        if last_tag =~ /\A(.+)\.(\d+)\z/
          # If the last tag was a \d\d\d\d.\d\d format....and we're not on the master branch, then don't offer an automated next tag name.
          last_tag_prefix = $1
          last_tag_number = $2
          if branch_name == "master"
            if last_tag =~ /\A\d{4}\.\d{1,3}\z/ 
              # We're on master and we have a propertly formattd release tag as the previous tag
              current_year = Time.now.to_date.year

               # If we're in a New Year, reset the release number
              if current_year == last_tag_prefix.to_i
                next_tag_number = "#{last_tag_prefix}.#{last_tag_number.to_i + 1}"
              else
                next_tag_number = "#{current_year}.1"
              end
            end
          else
            # If we're on a non-master branch, don't offer up a next tag number if the previous tag looks like an actual release tag number
            if last_tag =~ /\A\d{4}\.\d{1,3}\z/ 
              next_tag_number = nil
            else
              next_tag_number = "#{last_tag_prefix}.#{last_tag_number.to_i + 1}"
            end
          end
        end
      end

      [last_tag, next_tag_number]
    end

    def get_user_tag branch_name
      accepted = false
      tag_to_use = nil
      while (!accepted) do
        tag_to_use = get_user_response("Enter tag name", input_test: lambda {|v| v.blank? ? "You must enter a tag." : nil })
        accepted = get_user_response("Are you sure you want to tag the branch #{branch_name} with '#{tag_to_use}'? ", default_value: "Y") == "Y"
        tag_to_use = nil unless accepted
      end

      tag_to_use
    end
end

# Instantiate the class to define the tasks:
TagTasks.new

# This makes it possible to run the tag:auto task as the default task for the tag namespace -> `rake tag` is the equivalent of `rake tag:auto`
task tag: ["tag:auto"]