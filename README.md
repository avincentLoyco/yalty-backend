yalty API server
================

[![Build Status](https://magnum.travis-ci.com/yalty/yalty-backend.svg?token=35p5MLza67zdcUbXZDsS&branch=master)](https://magnum.travis-ci.com/yalty/yalty-backend) [![Code Climate](https://codeclimate.com/repos/5548cbaae30ba06b34000d53/badges/66b6a34fcae4e5ad3f80/gpa.svg)](https://codeclimate.com/repos/5548cbaae30ba06b34000d53/feed) [![Test Coverage](https://codeclimate.com/repos/5548cbaae30ba06b34000d53/badges/66b6a34fcae4e5ad3f80/coverage.svg)](https://codeclimate.com/repos/5548cbaae30ba06b34000d53/coverage)

Requireements
-------------

Following dependencies is required:

* [Git](http://git-scm.com/)
* [Ruby 2.2](https://www.ruby-lang.org/)
* [Bundler](http://bundler.io/)
* [Postgres 9.3](http://www.postgresql.org/)

Following decencies is recommended, default configuration and
setup instruction require them:

* [pow](http://pow.cx/) on OS X
* [prax](http://ysbaddaden.github.io/prax/) on Linux

[homebrew](http://brew.sh/) is recommended on OS X to install dependencies. For
the installation of required version of ruby you can use
[rbenv](https://github.com/sstephenson/rbenv) which can be installed thought
homebrew.


Prepare development (& testing) environment
-------------------------------------------

Start by cloning repository and move in working directory, then installing
above requirements and configure *pow* to use *api.yalty.dev* and
*launchpad.yalty.dev* hosts:

```bash
ln -sf `pwd` ~/.pow/api.yalty
ln -sf `pwd` ~/.pow/launchpad.yalty
```

Now you need to run *bundler* in working directory. Then you can edit local
configuration (*.env.local*) if you need to change any default value.

install gems dependencies:
```bash
bundle install
```

On Linux, ensure method is set to *trust* in `pg_hba.conf` file.

Then, create a postgres superuser role if not exist and setup databases:
```bash
createuser -s rails
rake db:create:all db:setup
```

Setup the application:
```bash
rake setup
```

Make sure everything is ok by running specs:
```bash
bin/rspec
```


Running development
-------------------

TODO: using *postman* to access to API, describe how to get an access token to
do this.


Running tests
-------------

Before run, you need to follow above instructions to prepare testing
environment. Then you can run test with rspec command or guard when you are
in active development. All tests run on
[Travis CI](https://magnum.travis-ci.com/yalty/yalty-backend)
when code is pushed on repository.

```bash
bin/rspec
guard
```


How to deploy
-------------

TODO

Known issues
------------

With *prax* and *RVM*, ensure RVM works. To do that you can follow instruction
from [prax wiki](https://github.com/ysbaddaden/prax/wiki/Ruby-Version-Managers).
