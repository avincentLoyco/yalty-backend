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

lvh.me as alternative for pow. Run server like that and then app will be available
under: `api.yalty.lvh.me:3000` and `launchpad.yalty.lvh.me:3000`:

```bash
rails s -p 3000 -b lvh.me
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

The API can be acceded through the API endpoint (http://api.yalty.dev) with a
user token. You can also use the frontend if you have its development
environment.

To load an account and get user credentials, run the following command:
```bash
rake yalty:load_sample_account
```

An account for "My Company" with a user is created (or loaded when it exists) and
the user credentials displayed.

API use *Authentication* header with *bearer* token.

You can use the following command if you want a complete set of sample data:
```bash
rake yalty:load_sample_data
```

### Postman

If you want to test api with Postman you have to run rails server first (with lvh.me or pow) and you have to have valid user's access token. You can obtain it with:
```ruby
Account::User.last.access_token
```

List of available routes and their http methods may be obtained by:
```bash
rake routes
```

#### Examples (with lvh.me usage)

Required headers:
```
Content-Type:    application/vnd.api+json
Accept:          application/vnd.api+json
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


How to deploy
-------------

Add git remotes:

```bash
git remote add review git@scalingo.com:yalty-api-server-review.git
git remote add staging git@scalingo.com:yalty-api-server-staging.git
git remote add production git@scalingo.com:yalty-api-server-production.git
```

For review, checkout branch to deploy and run deploy task:

```bash
git checkout <branch>
rake deploy:review
```

or deploy master to staging:
```bash
rake deploy:staging
```

or deploy stable to production:
```bash
rake deploy:production
```

Known issues
------------

With *prax* and *RVM*, ensure RVM works. To do that you can follow instruction
from [prax wiki](https://github.com/ysbaddaden/prax/wiki/Ruby-Version-Managers#rvm).

With *prax* and *Chrome*, the .dev urls may not work. You can follow instructions
from this issue [Chrome can't resolve .dev domains #117](https://github.com/ysbaddaden/prax/issues/117#issuecomment-78342316), by creating the script and restarting the network-manager.
