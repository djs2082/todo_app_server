class ChangeSettingsValueToString < ActiveRecord::Migration[7.1]
  def up
    # Preserve existing JSON data by converting each value to a compact JSON string if not scalar.
    add_column :settings, :value_text, :text

    Setting.reset_column_information
    say_with_time "Migrating settings.value (json) -> value_text (text)" do
      Setting.find_each(batch_size: 100) do |s|
        raw = s[:value]
        serialized = case raw
                     when String, Numeric, TrueClass, FalseClass, NilClass
                       raw.to_s
                     else
                       raw.to_json
                     end
        s.update_column(:value_text, serialized)
      end
    end

    remove_column :settings, :value
    rename_column :settings, :value_text, :value
  end

  def down
    add_column :settings, :value_json, :json

    Setting.reset_column_information
    say_with_time "Reconstructing JSON from string (best effort)" do
      Setting.find_each(batch_size: 100) do |s|
        parsed = begin
          JSON.parse(s[:value])
        rescue JSON::ParserError
          s[:value]
        end
        s.update_column(:value_json, parsed)
      end
    end

    remove_column :settings, :value
    rename_column :settings, :value_json, :value
  end
end