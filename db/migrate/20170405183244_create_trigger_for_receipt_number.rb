class CreateTriggerForReceiptNumber < ActiveRecord::Migration
  def up
    execute <<-SQL
      CREATE SEQUENCE receipt_number_seq;

      CREATE OR REPLACE FUNCTION assign_receipt_number()
        RETURNS "trigger" AS
          $BODY$
            BEGIN
              NEW.receipt_number:=nextval('receipt_number_seq');
              Return NEW;
            END;
          $BODY$
        LANGUAGE 'plpgsql' VOLATILE;

      CREATE TRIGGER receipt_number_generator
        BEFORE UPDATE
        ON invoices
        FOR EACH ROW
        WHEN (OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'success')
        EXECUTE PROCEDURE assign_receipt_number();
    SQL
  end

  def down
    execute <<-SQL
      DROP TRIGGER receipt_number_generator ON invoices;
      DROP FUNCTION assign_receipt_number();
      DROP SEQUENCE receipt_number_seq;
    SQL
  end
end
