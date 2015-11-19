require 'test/unit'
require 'shoulda'
require 'csv'
require 'find'
require 'yaml'
require 'uri'
require 'cgi'
require 'open-uri'

class MappingTest < Test::Unit::TestCase
  MAPPING_DIR = './mappings'
  SCHEMA_DIR = './schemas'

  # Run the tests for every mapping we have
  Find.find(MAPPING_DIR) do |path|
    next if !File.exist?(path) || path.match(/\.yml$/) == nil

    context "mapping:#{path}" do
      subject { YAML.load_file(path) }

      should "have a schema" do
        assert_not_nil subject["schema"]
      end

      should "have valid source info" do
        assert_not_nil subject["source"]
        assert_not_nil subject["source"]["name"]
        assert_not_nil subject["source"]["url"]

        # Verify the actual URL
        parsed_url = subject["source"]["url"].scan(URI.regexp)
        assert_not_nil parsed_url, "URL did not parse as valid"
        assert parsed_url.length > 0, "URL did not parse as valid"
      end

      should "map to a valid schema" do
        assert File.exist?(File.join(SCHEMA_DIR, subject["schema"] + ".yml")),
          "does not have a valid schema"
      end

      should "have a valid mapping" do
        # Verify the actual URL
        assert_not_nil subject["mapping"]
        assert_not_nil subject["mapping"]["base"]
        assert_match URI.regexp, subject["mapping"]["base"], "Query did not parse as valid"
      end

      should "have output that matches the schema" do
        query = subject["mapping"]["query"].merge({"$limit" => 1})
        url = subject["mapping"]["base"] + "?" + query.collect{ |k,v| "#{k}=#{v}" }.join("&")

        # Check the constructed URL
        assert_match URI.regexp, url, "query URL is invalid"

        output = begin
                   open(url)
                 rescue Exception => e
                   fail "Exception raised fetching \"#{url}\": #{e.inspect}"
                 end

        # Make sure we got the right content type back
        assert_match %r{text/csv}, output.content_type, "content type was invalid"

        # Make sure we can parse the CSV
        csv = begin
                CSV.parse(output.read, :headers => true)
              rescue Exception => e
                fail "Exception raised parsing output: #{e.inspect}"
              end

        # Load the schema and make sure we can match the headers
        schema = YAML.load_file(File.join(SCHEMA_DIR, subject["schema"] + ".yml"))
        schema["columns"]
          .reject { |c| c["optional"] }
          .collect { |c| c["field_name"] }
          .each { |c|
            assert csv.headers.index(c), "column \"#{c}\" not found in output"
          }
      end
    end
  end
end
