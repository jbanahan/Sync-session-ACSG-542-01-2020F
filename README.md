# VFI Track

VFI Track is the primary application developed by Vandegrift, Inc.  It runs atop the Amazon Web Services Cloud.

## Docker development environment

For local docker development environment you should first build the container, install dependecies and run migrations with:
```
docker-compose build # This is actually optional, docker should build whatever container you attempt to use
docker-compose run runner .dockerdev/setup
```

To run the environment
```
docker-compose up rails
```

Some recommended Docker aliases to put into your `~/.bashrc`
```
alias dcr='docker-compose run'
alias dcu='docker-compose up'
alias dcd='docker-compose down'
alias dcb='docker-compose build'
```

Some helpful examples:
```
dcu rails
dcr runner rails c
```

### Testing

To run all specs run the testing service
```
dcr testing
```

To run a particular test, just append the file and/or line number you wish to run
```
dcr testing spec/models/address_spec.rb:132
```

### Code Style

Automatically check code style before creating a pull request to the master branch with Rubocop.
```
rubocop --safe-auto-correct
```

Alternatively, use the rake commands listed in `rubocop.rake` to speed up the process by including parallelism and/or only testing the differences between the current branch and master.
```
rake rubocop:scan      # Parallel enabled
rake rubocop:branch    # Parallel and only against changes
rake rubocop:branch_ac # Against changes and auto correct
```

## Staging a New Build

**_DO NOT_** stage a new build until the Circle CI build dashboard shows a clean (green) build on the master branch.


VFI Track's upgrade process relies on git tags to know which version to deploy to the servers.  To that end, any developer with commit access on this
repository can stage a build.

### To stage a build:

1. Ensure your local git repository that is linked to the "master" Vandegrift repository has no uncommitted or staged commits.  `git status` should report nothing to commit.

1. Ensure your local git is synced with the "master" repo by running `git pull`.

1. Verify the current tag by running `cat config/version.txt`.  The value should be like YYYY.#.  Increment the number by one for the &lt;version&gt; tag used in the following step

1. Increment the deployment number from the previous step by one and then run `script/tag_version <version> master`

This will update the config/version.txt file, will add a tag of &lt;version&gt; to the HEAD of the master branch, and push those changes to the master repo.



## Deployment Steps

VFI Track runs across 4 AWS EC2 instances.  3 web servers and 1 backend job server.  All four instances can be updated through the VFI Track web application.

If the deployment involves upgraded or new GEMS, you MUST manually install the gems ahead of time on each server.  See the "Common Deploy Failure Causes" below for instructions.


1. Navigate to the Master Setups edit page of the instance you wish to upgrade: https://&lt;instance&gt;.vfitrack.net/master_setups/1/edit

1. Ensure the delayed job queue is empty (or at least that there are no long running jobs that will cause problems if updated code is deployed).<p>During a deploy, the delayed job queues are all shut down and then restarted automatically by a backend service script, however, any running job is left to continue running until it completes.  This shouldn't cause an issue EXCEPT if the new deployment does something like introduce backwards incompatible schema changes or class modifications.</p>
1. Click the "Upgrade" button, key the &lt;version&gt; you wish to deploy into the popup's textbox and click the "Ok" button.
1. The deploy should take less than a minute (unless there are migrations that take a bit of time), you can follow the progress of deploy by clicking into the Upgrade Logs links in the Instances section of the Master Setups page.
1. The deployment is complete when there is no longer a "Running" status next to the topmost Upgrade Log of each of the 4 newest instances listed.  There should be nothing left for you to do, the deployment is completed.


Once the Upgrade is complete, the code that runs the upgrade signals to the Passenger application instance to restart itself (it touches tmp/restart.txt).  On the job server, a background process runs every minute and restarts job queues if they are shut down.


## Fixing Errors

Occasionally errors will arise when deploying.  If this happens you will have to manually ssh into the EC2 instances to fix the errors.  You can see what the error was by clicking into the Upgrade Log showing as errored.


There is no direct way to access the EC2 instances, you must ssh into the access.vfitrack.net jump server (.ie `ssh <yourname>@access.vfitrack.net`) and from there ssh into the ec2 instance needing attention.  Your public key will need to be utilized to log into the access.vfitrack.net.  To access the ec2 instance your account on access will need to have the AWS public key.  Once logged into the access server you can access the EC2 instances by the IP address and using the ubuntu user.  The hostname on the Master Setups page lists their IP address (.ie `ssh ubuntu@10.123.211.123`)

Once you are logged into the machine and resolve the issue (see issue list below) you should delete the 'tmp/upgrade_running.txt' file under the instance's directory.

Shortly after the is delete, the upgrade should attempt to run again.  Make sure you clear every instance that lists errors.


## Common Deploy Failure Causes

1. Long Running Migrations - In order to ensure only a single process is running a migration at a time, a database lock is utilized.  The other processes will wait at most 10 minutes for the lock to be released.  After 10 minutes they will cancel the upgrade.  If the migration legitimately lasts for more than 10 minutes and clears, then you must simply log into the EC2 instances that showed as failed and delete the tmp/upgrade_running.txt file from the server instance being upgraded.  The server will then re-run the upgrade, which should complete without error now since the long running migration is cleared.

1. New GEMS are installed - There's something not quite right about how the user environment is set up with the upgrade and it fails when trying to install new Gems.  To that end, before doing any deploys that upgrade or deploy new gems you should log into EACH production system and install the Gems manually using the gem version listed in the Gemfile.lock file `gem install gem_name -v <version>`.  If you do this before the deploy, it will not fail.  If you fail to do this, the build will fail and you will need to log into each server and you can manually run `bundle install` from the instance directory.
