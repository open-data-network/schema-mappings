require 'test/unit'
require 'shoulda'
require 'csv'
require 'find'
require 'yaml'
require 'uri'

class SchemaTest < Test::Unit::TestCase
  SCHEMA_DIR = './schemas'

  # Run the tests for every schema we have
  Find.find(SCHEMA_DIR) do |path|
    next if !File.exist?(path) || path.match(/\.yml$/) == nil

    context "schema:#{path}" do
      subject { YAML.load_file(path) }

      should "have a name" do
        assert_not_nil subject["name"]
      end

      should "have a valid url" do
        assert_not_nil subject["url"]

        # Verify the actual URL
        parsed_url = subject["url"].scan(URI.regexp)
        assert_not_nil parsed_url, "URL did not parse as valid"
        assert parsed_url.length > 0, "URL did not parse as valid"
      end

      should "list benefits" do
        assert_not_nil subject["benefits"]
      end

      should "have at least one column" do
        assert subject["columns"] && subject["columns"].length > 0, "has no columns"
      end

      should "have valid columns" do
        subject["columns"].each do |col|
          assert_not_nil col["name"], "has no name: #{col.inspect}"

          name = col["name"]
          assert_not_nil col["field_name"], "#{name} has no field_name: "
          assert_not_nil col["description"], "#{name} has no description"
          assert_not_nil col["data_type"], "#{name} has no data_type"
          assert ["text", "number"].include?( col["data_type"] ), "#{name} has an invalid data_type"
          assert [nil, false, true].include?(col["optional"]), "#{name}: optional is not nil or a boolean"
        end
      end
    end
  end
end
