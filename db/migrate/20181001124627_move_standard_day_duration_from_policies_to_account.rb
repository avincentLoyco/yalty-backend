class MoveStandardDayDurationFromPoliciesToAccount < ActiveRecord::Migration
  def change
    # NOTE: For the date 19.09.2018 we have ~500 accounts that don't have any
    # active non-reset presence policy. Those are probably inactive accounts.
    # This issue is connected with the Migration when all presence policies
    # and time off policies created before 2018-01-01 were set as inactive.
    # Each account with deactivated policies was contacted to setup new policies
    # on its own, but many accounts haven't done that.
    # Each account should have default full time active presence policy assigned so
    # the calculations for time offs can be properly executed.

    create_missing_active_presence_policies

    add_column :accounts, :standard_day_duration, :float
    add_reference :accounts, :default_full_time_presence_policy, index: true, type: :uuid
    add_foreign_key :accounts, :presence_policies,
      column: :default_full_time_presence_policy_id, on_delete: :nullify

    update_standard_day_duration_and_default_full_time_presence_policy

    remove_column :presence_policies, :standard_day_duration
    remove_column :presence_policies, :default_full_time
  end

  private

  def create_missing_active_presence_policies
    missing_presence_policies_account_ids.each do |account_id|
      create_missing_presence_policy(account_id)
    end
  end

  def missing_presence_policies_account_ids
    # select all the accounts that don't have any active non-reset presence policy
    join_query = <<-SQL
      LEFT JOIN presence_policies ON presence_policies.account_id = accounts.id
      AND presence_policies.reset IS FALSE
      AND presence_policies.active IS TRUE
    SQL
    Account.joins(join_query).where("presence_policies.account_id IS NULL").pluck(:id)
  end

  def create_missing_presence_policy(account_id)
    now_query = "CAST(NOW() at time zone 'utc' AS timestamp)"

    presence_policy_id = insert <<-SQL
      INSERT INTO presence_policies (account_id, name, occupation_rate, standard_day_duration, default_full_time, created_at, updated_at)
      VALUES ('#{account_id}', 'Default full time', 1.0, 510, true, #{now_query}, #{now_query})
    SQL
    # from Monday to Friday
    (1..5).each do |order|
      presence_day_id = insert <<-SQL
        INSERT INTO presence_days (presence_policy_id, "order", minutes, created_at, updated_at)
        VALUES ('#{presence_policy_id}', #{order}, 510, #{now_query}, #{now_query})
      SQL
      insert <<-SQL
        INSERT INTO time_entries (presence_day_id, start_time, end_time, duration, created_at, updated_at)
        VALUES
          ('#{presence_day_id}', '8:00', '12:00', 240, #{now_query}, #{now_query}),
          ('#{presence_day_id}', '14:00', '18:30', 270, #{now_query}, #{now_query})
      SQL
    end
    # Saturday and Sunday
    (6..7).each do |order|
      insert <<-SQL
        INSERT INTO presence_days (presence_policy_id, "order", minutes, created_at, updated_at)
        VALUES ('#{presence_policy_id}', #{order}, 0, #{now_query}, #{now_query})
      SQL
    end
  end

  def update_standard_day_duration_and_default_full_time_presence_policy
    execute <<-SQL
      UPDATE accounts
      SET
        standard_day_duration = CASE WHEN q.day_duration IS NOT NULL
          THEN q.day_duration ELSE q.standard_day_duration END,
        default_full_time_presence_policy_id = q.presence_policy_id
      FROM
      (
        -- Accounts that have active default full-time presence policy defined
        SELECT
          a.id AS account_id,
          pp.id AS presence_policy_id,
          SUM (pd.minutes)::float / COUNT (pd.id) AS day_duration,
          pp.standard_day_duration AS standard_day_duration
        FROM accounts AS a
        JOIN presence_policies AS pp
          ON pp.account_id = a.id
            AND pp.active IS TRUE
            AND pp.reset IS FALSE
        LEFT JOIN presence_days AS pd
          ON pd.presence_policy_id = pp.id
          AND pd.minutes IS NOT NULL AND pd.minutes <> 0
        WHERE pp.default_full_time IS TRUE
        GROUP BY a.id, pp.id, pp.standard_day_duration

        UNION

        -- Accounts without active full-time presence policy,
        -- duration_day is got from the presence policy with the greatest standard_day_duration
        SELECT
          pp.account_id,
          pp.id AS presence_policy_id,
          SUM (pd.minutes)::float / COUNT (pd.id) AS day_duration,
          pp.standard_day_duration AS standard_day_duration
        FROM presence_policies AS pp
        LEFT JOIN presence_days AS pd
          ON pd.presence_policy_id = pp.id
          AND pd.minutes IS NOT NULL AND pd.minutes <> 0
        LEFT JOIN presence_policies AS pp2
          ON pp.account_id = pp2.account_id
            AND pp.standard_day_duration < pp2.standard_day_duration
        JOIN accounts AS a
          ON pp.account_id = a.id
        WHERE
          pp.account_id NOT IN
          -- Accounts without default full-time presence policy
          (
            SELECT a.id
            FROM accounts AS a
            JOIN presence_policies AS pp
              ON pp.account_id = a.id
                AND pp.active IS TRUE
                AND pp.reset IS FALSE
            WHERE pp.default_full_time IS TRUE
          )
          AND pp2.id IS NULL
          AND pp.active IS TRUE
          AND pp.reset IS FALSE
        GROUP BY pp.account_id, pp.id, pp.standard_day_duration
      ) AS q
      WHERE accounts.id = q.account_id
    SQL
  end
end
