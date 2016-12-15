# All server share the same deploy directory (shared fs)
server '10.128.101.11', roles: %w(api launchpad), primary: true
server '10.128.101.12', roles: %w(api launchpad),                 no_release: true
server '10.128.103.11', roles: %w(worker db),     primary: true,  no_release: true
