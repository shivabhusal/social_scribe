#!/usr/bin/env ruby
# frozen_string_literal: true
REGEXP = /^(.+):[\s"'].?(.+)[\s'"]$/
ENV_FILE =
  if File.exist?(".env.production")
    ".env.production"
  elsif File.exist?(".env")
    ".env"
  else
    abort "❌ No .env.production or .env file found"
  end

puts "🔐 Loading secrets from #{ENV_FILE}"

count = 0

File.foreach(ENV_FILE) do |line|
  line = line.strip

  # Skip empty lines and comments
  next if line.empty? || line.start_with?("#")

  key, value = line.match(REGEXP)&.captures
  next if key.nil? || value.nil?

  key = key.strip
  value = value.strip

  # Remove surrounding quotes if present
  if (value.start_with?('"') && value.end_with?('"')) ||
     (value.start_with?("'") && value.end_with?("'"))
    value = value[1..-2]
  end
  puts "➡️  Setting #{key}"

  # Safe execution (no shell interpolation)
  success = system("fly", "secrets", "set", "#{key}=#{value}")

  abort "❌ Failed to set secret: #{key}" unless success

  count += 1
end

puts "✅ #{count} secrets successfully loaded to Fly.io"
