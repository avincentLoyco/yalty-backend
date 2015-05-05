yalty API server
================

Requireements
-------------

Following dependencies is required:

* Ruby 2.2
* Bundler
* Postgres 9.3

Prepare development (& testing) environment
-------------------------------------------

Before run, you need to install required dependencies and run
`bundle` in working directory.

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

TODO

How to deploy
-------------

Before deploy, you need to install required dependencies and run
`bundle` in working directory.

```bash
bundle install
```

TODO
