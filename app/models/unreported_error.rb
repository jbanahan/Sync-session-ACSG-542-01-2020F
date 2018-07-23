# This error can be raised in a web or delayed job context and it will NOT be reported.
# Any log_me calls on it will be swallowed, and 3rd party logging will be set up to ignore it too.
# Further, if raised from a delayed job context, the job will NOT re-run.

# When raised from an API context, a json response is returned of {errors: [error_message]}
#
# When raised from an HTTP context, the user will be presented with an error just like they would
# had you raised a StandardError, however, the error will not be emailed to the bug list, or captured in NewRelic.
#
# When raised from a delayed job context, the job will be killed and will not requeue.  No notification of the error
# will be made.

class UnreportedError < StandardError

end