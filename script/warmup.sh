#!/bin/bash

# bdemo is first since that's the catchall instance and the one that the load balancer hits for the "health" check
curl --header 'Host: bdemo.vfitrack.net' 'http://localhost/user_sessions/new'
curl --header 'Host: www.vfitrack.net' 'http://localhost/user_sessions/new'
curl --header 'Host: polo.vfitrack.net' 'http://localhost/user_sessions/new'
curl --header 'Host: ann.vfitrack.net' 'http://localhost/user_sessions/new'
curl --header 'Host: underarmour.vfitrack.net' 'http://localhost/user_sessions/new'
curl --header 'Host: pepsi.vfitrack.net' 'http://localhost/user_sessions/new'
curl --header 'Host: warnaco.vfitrack.net' 'http://localhost/user_sessions/new'
curl --header 'Host: das.vfitrack.net' 'http://localhost/user_sessions/new'
curl --header 'Host: jcrew.vfitrack.net' 'http://localhost/user_sessions/new'
curl --header 'Host: ll.vfitrack.net' 'http://localhost/user_sessions/new'
curl --header 'Host: rhee.vfitrack.net' 'http://localhost/user_sessions/new'
