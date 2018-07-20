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
above requirements

lvh.me as a DNS mapper to localhost. We need it to access subdomains. Run server like that and then app will be available
under: `api.yalty.lvh.me:3000` and `launchpad.yalty.lvh.me:3000`:

```bash
rails s
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

Get a key on [Google API console](https://code.google.com/apis/console/) and add it in
`.env.local` file under `GOOGLE_API_KEY` name, then enable following services:

* Google Maps Time Zone API
* Google Maps Geocoding API


Get keys from [stripe dashboard](https://dashboard.stripe.com/account/apikeys) and add them in
`.env.local` file under `STRIPE_PUBLISHABLE_KEY`, `STRIPE_SECRET_KEY` name, then enable following services:

Running development
-------------------

The API can be acceded through the API endpoint (http://api.yalty.dev) with a
user token. You can also use the frontend if you have its development
environment.


API use *Authentication* header with *bearer* token.


### Postman

If you want to test api with Postman you have to run rails server first (with lvh.me or pow) and you have to have valid user's access token. You can obtain it with:
```ruby
Account::User.last.access_token
```

List of available routes and their http methods may be obtained by:
```bash
rake routes
```

#### User permitions

We use for permitions gem called: [CanCanCan](https://github.com/CanCanCommunity/cancancan)

#### Examples (with lvh.me usage)

Required headers:
```
Content-Type:    application/json
Accept:          application/json
Authorization:   Bearer YOUR_ACCESS_TOKEN
```

GET for receiving list of working places:
```
http://api.lvh.me:3000/api/v1/working-places
```

POST for adding employee to working place
```
http://api.lvh.me:3000/api/v1/working-places/WORKING_PLACE_ID/relationships/employees
```
body:
```
{
  "data": [
    { "type": "employees", "id": "first_employee_id" },
    { "type": "employees", "id": "second_employee_id" }
  ]
}
```

DELETE for removing employee from working place
```
http://api.lvh.me:3000/api/v1/working-places/WORKING_PLACE_ID/relationships/employees/EMPLOYEE_ID
```

Generating Account::RegistrationKey Tokens
------------------------------------------

```
rake generate:registration_key_token
```

By default task generates 10 keys.


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

Running faster RSpec tests
-------------

Instead of running `rspec spec` run `rake parallel:spec` to have a faster development test time by using [parallel_tests](https://github.com/grosser/parallel_tests)

Run this commands once:
```bash
rake parallel:create
rake parallel:prepare # repeate after migration
```

Run each time:
```bash
rake parallel:spec
```

How to deploy
-------------

First, install [docker](https://docs.docker.com/engine/installation/). Review environment is
automatically deploy, but for staging and production you should use capitrano.
[Hub](https://hub.github.com/), the git extension for Github is also required to create Pull
Request.

You must add following lines to your `.ssh/config` file:
```
Host 10.128.*.*
  User <hosting ssh username>
```

and verify you don't have theses lines uncommented in your `/etc/ssh/ssh_config` file:
```
Host *
  SendEnv LANG LC_*
```

To deploy release candidate to staging, run following commands. The release branch is automatically
created, pushed on git, and a pull request created, then wait on the docker build (you can see build
status on the release branch pull request). Don't forgot to logged in with docker and hub cli.
```bash
git checkout <branch to release> && git pull && bundle

# optionnal if you are already logged in
docker login
hub ci-status

./bin/cap staging release:candidate
# ... waiting on docker build ...
./bin/cap staging deploy
```

Before deploying on staging you can run following commands to reset the database to
a production state (usefull to have fresh data or test database migration).
```bash
git checkout releases/X.X.X && git pull && bundle

# optionnal if you are already logged in
docker login

./bin/cap production db:download
./bin/cap staging sync
```

To deploy a release on production, run following commands. The release tag is automatically created
and pushed on git and docker, then you can deploy and merge the release pull request.
```bash
git checkout releases/X.X.X && git pull && bundle

./bin/cap production release:approve
./bin/cap production deploy
```

Known issues
------------
Postgres policy doesn't allow adding columns with the default values and  NULL marker. Thus rails shortcuts as below are not allowed:
```ruby
add_column :users, :age, :integer, default: 0
```
The correct migration flow is:
* add column
* add default value and NULL marker
* update existing records

Example: 
```ruby
add_column :users, :age, :integer
change_column_default :users, :age, 0
change_column_null :users, :age, false
execute("UPDATE users SET age = 0")
```

TODO
------------
Update staging to have the same PG configuration as production, including policies
