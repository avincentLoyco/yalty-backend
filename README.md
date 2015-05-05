yalty API server
================

[![Build Status](https://magnum.travis-ci.com/yalty/yalty-server.svg?token=35p5MLza67zdcUbXZDsS&branch=master)](https://magnum.travis-ci.com/yalty/yalty-server) [![Code Climate](https://codeclimate.com/repos/5548cbaae30ba06b34000d53/badges/66b6a34fcae4e5ad3f80/gpa.svg)](https://codeclimate.com/repos/5548cbaae30ba06b34000d53/feed) [![Test Coverage](https://codeclimate.com/repos/5548cbaae30ba06b34000d53/badges/66b6a34fcae4e5ad3f80/coverage.svg)](https://codeclimate.com/repos/5548cbaae30ba06b34000d53/coverage)

Requireements
-------------

Following dependencies is required:

* Ruby 2.2
* Bundler
* Postgres 9.3

Prepare development (& testing) environment
-------------------------------------------

Before run, you need to install required dependencies and run
`bundle` in working directory. Then you can edit local configuration
(`.env.local`) if you need to change any default value.

install gems dependencies:
```bash
bundle install
```

create postgres role if not exist and setup databases:
```bash
createuser --createdb -R -S rails
rake db:setup
```

Running tests
-------------

Before run, you need to install required dependencies and run
`bundle` in working directory. Then you can run test with rspec command
or guard when you are in active development. All tests run on
[Travis CI](https://magnum.travis-ci.com/yalty/yalty-server)
when code is pushed on repository.

```bash
bundle install
```

```bash
bin/rspec
guard
```

How to deploy
-------------

Before deploy, you need to install required dependencies and run
`bundle` in working directory.

```bash
bundle install
```

TODO
