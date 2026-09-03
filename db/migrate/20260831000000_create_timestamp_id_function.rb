# frozen_string_literal: true

class CreateTimestampIdFunction < ActiveRecord::Migration[7.1]
  def up
    safety_assured do
      execute <<~SQL
        CREATE OR REPLACE FUNCTION timestamp_id(table_name text)
        RETURNS bigint
        LANGUAGE plpgsql
        IMMUTABLE
        AS $$
        BEGIN
          RETURN (EXTRACT(EPOCH FROM clock_timestamp()) * 1000)::bigint;
        END;
        $$;
      SQL
    end
  end

  def down
    safety_assured do
      execute <<~SQL
        DROP FUNCTION IF EXISTS timestamp_id(text);
      SQL
    end
  end
end
