require 'open3'

# This class is a simple wrapper around running a parsing some git commands to provide
# a layer of abstraction to the calling code.
module OpenChain; class Git

  # This method will return the HEAD branch / tag name that we're currently set at.
  def self.current_tag_name allow_branch_name: false
    stdout, stderr, status = Open3.capture3("git status")
    raise "Failed to return tag name: #{stderr}" unless status.success?

    # If you've checkout out to a specific tag, git status shows a message like:
    # HEAD detached at #{tag_name}

    # If you're on a branch, it shows:
    # On branch #{branch}

    # In production, we should NEVER not be running from a tag...however locally we're very
    # likely to just be running from a branch, hence the allow_branch_name option and allowing returning
    # the branch name instead of the strict tag name.
    tag = nil
    if stdout =~ /HEAD detached at (.*)/i
      tag = $1
    elsif allow_branch_name && stdout =~ /On branch (.*)/i
      tag = $1
    end

    raise "Failed to discover current git tag name." if tag.blank?

    tag
  end

end; end;