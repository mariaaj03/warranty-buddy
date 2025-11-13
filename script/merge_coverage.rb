require 'simplecov'
require 'json'

SimpleCov.coverage_dir 'coverage/merged'

# Ensure both coverage result files exist
rspec_path = 'coverage/rspec/.resultset.json'
cucumber_path = 'coverage/cucumber/.resultset.json'

unless File.exist?(rspec_path) && File.exist?(cucumber_path)
  abort "❌ Missing one of the coverage result files. Run both `rspec` and `cucumber` first."
end

# Read and merge both
rspec_results = JSON.parse(File.read(rspec_path))
cucumber_results = JSON.parse(File.read(cucumber_path))
merged = rspec_results.merge(cucumber_results)

# Write to root so SimpleCov merger can find it
File.write('coverage/.resultset.json', JSON.pretty_generate(merged))

# Merge and generate combined report
result = SimpleCov::ResultMerger.merged_result
if result
  result.format!
  puts "✅ Merged report created at coverage/merged/index.html"
else
  abort "❌ No coverage data found to merge. Check .resultset.json paths or rerun test suites."
end
