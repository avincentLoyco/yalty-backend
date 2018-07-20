# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)


# ======================================================================
# =========================== ACCOUNTS =================================
# ======================================================================

account =
  Account.create(
    subdomain: "seed",
    company_name: "seed",
    default_locale: "en",
    timezone: "Europe/Warsaw",
    referred_by: nil,
    customer_id: "cus_CqD00X6ofMt0TM",
    subscription_renewal_date: nil,
    subscription_id: "sub_CqD1PufISDXF66",
    company_information: {
      company_name: "seed",
      address_1: nil,
      address_2: nil,
      city: nil,
      postalcode: nil,
      country: nil,
      region: nil,
      phone: nil
    },
    invoice_emails: nil,
    available_modules: { data: [] },
    archive_processing: false,
    last_employee_journal_export: nil
  )

# ===================================================================
# ============================ EMPLOYEES ============================
# ===================================================================

owner_employee =
  Employee.new(
    account_id: account.id,
    account_user_id: nil
  )

user_employee =
  Employee.new(
    account_id: account.id,
    account_user_id: nil
  )

owner_employee.save(validate: false)
user_employee.save(validate: false)

# ===================================================================
# ============================== USERS ==============================
# ===================================================================

owner =
  Account::User.new(
    email: "some_email@mail.com",
    password: "password1",
    account_id: account.id,
    reset_password_token: nil,
    role: "account_owner",
    locale: nil,
    balance_in_hours: false,
    employee: owner_employee
  )

user =
  Account::User.new(
    email: "some_email2@mail.com",
    password: "password2",
    account_id: account.id,
    reset_password_token: nil,
    role: "user",
    locale: nil,
    balance_in_hours: false,
    employee: user_employee
  )

owner.save!
user.save!

# ===================================================================
# =================== COMPANY EVENTS ================================
# ===================================================================

company_event =
  CompanyEvent.create(
    title: "Company Event Title",
    effective_at: DateTime.now,
    comment: "Company Event Comment",
    account_id: account.id
  )


# ===================================================================
# =================== INVOICES ======================================
# ===================================================================

invoice =
  Invoice.create(
    invoice_id: "invoice_id",
    amount_due: 666,
    status: "pending",
    date: DateTime.now,
    account_id: account.id
  )
