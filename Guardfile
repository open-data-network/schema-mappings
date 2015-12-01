guard :test do
  # Tests themselves
  watch(%r{^test/test_.+\.rb$})

  # schemas and mappings
  watch(%r{^(.+)/.*$}) { |m| "test/test_#{m[1]}.rb" }
end
