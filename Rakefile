require 'rake/testtask'
require 'soda/client'
require 'httparty'
require 'yaml'
require 'erb'
require 'fileutils'
require 'open-uri'

Rake::TestTask.new do |t|
  t.libs << 'test'
end

desc 'Run tests'
task :default => :test

TEMPLATE = <<-ERB
name: "<%= @schema %> for <%= @customer %>"
schema: <%= @schema_key %>
description: "<%= @schema %> for <%= @customer %>"
source:
  name: "<%= @customer %>"
  url: "https://<%= @domain %>/d/<%= @uid %>"
mapping:
  base: "<%= @base %>"
ERB

# Update our mappings based on Socrata app configurations
task :update_auto_mappings do
  mappings = YAML.load_file('./auto_mappings.yml')
  template = ERB.new(TEMPLATE)
  schemas = {}

  mappings.each do |name, conf|
    # Fetch customer listings from Bellepheron
    customers = HTTParty.get(conf["query"])
    customers.each do |cust|
      begin
        # Check each mapping for that customer
        conf['datasets'].each do |ds|
          next if cust[ds['key']].nil? || cust[ds['key']].empty?

          # Fetch the schema, if we haven't already
          schemas[ds['schema']] ||= YAML.load_file(File.join('schemas', ds['schema'] + '.yml'))

          puts "Auto-mapping #{ds['schema']} for #{cust['string.customer_name']}..."

          # Build up our variables for our template
          @uid = cust[ds['key']]
          @domain = cust['dataset_domain']
          @customer = cust['string.customer_name']
          @schema_key = ds['schema']
          @schema = schemas[ds['schema']]['name']

          # Make sure we map into the 2.1 UID, because reasons
          res = HTTParty.get("https://#{@domain}/api/migrations/#{@uid}.json")
          next if res['nbeId'].nil? || res['nbeId'].empty?
          @base = "https://#{@domain}/resource/#{res['nbeId']}.csv"

          # Not all datasets listed are actually compliant. Let's check
          output = open(@base + '?$limit=1')
          raise "Did not get the expected content type back for #{@base}, got #{output.content_type} instead" if !output.content_type.match(%r{text/csv})

          csv_headers = CSV.parse(output.read, :headers => true).headers
          req_headers = schemas[ds['schema']]['columns']
            .reject { |c| c["optional"] }
            .collect { |c| c["field_name"] }
          missing = req_headers - csv_headers

          # Check columns
          if missing.size > 0
            raise "\"#{@customer}\" missing required headers for #{@base}: #{missing}"
          end

          result = template.result(binding)

          group, file = ds['schema'].split('/')
          path = File.join('mappings', @domain, group)
          FileUtils.mkdir_p(path)
          File.write(File.join(path, "#{file}.#{@uid}.yml"), result)
        end
      rescue RuntimeError => e
        $stderr.puts "Error \"#{e.message}\" creating mappings, skipping"
      rescue SocketError => e
        $stderr.puts "Connection error, skipping"
      end
    end
  end
end
