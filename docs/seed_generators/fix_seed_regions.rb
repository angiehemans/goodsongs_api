#!/usr/bin/env ruby
# frozen_string_literal: true

# fix_seed_regions.rb
# Fixes region data in band seed files:
#   - Replaces city-level regions with nil (only keeps actual states/provinces/nations)
#   - When city is nil but region is a known city, moves region to city
#   - Clears region when it duplicates city
#
# Usage:
#   ruby fix_seed_regions.rb db/seeds/musicbrainz
#
# Modifies seed files in-place.

require 'set'

VALID_REGIONS = {
  'US' => Set.new(%w[
    Alabama Alaska Arizona Arkansas California Colorado Connecticut Delaware
    Florida Georgia Hawaii Idaho Illinois Indiana Iowa Kansas Kentucky
    Louisiana Maine Maryland Massachusetts Michigan Minnesota Mississippi
    Missouri Montana Nebraska Nevada New\ Hampshire New\ Jersey New\ Mexico
    New\ York North\ Carolina North\ Dakota Ohio Oklahoma Oregon Pennsylvania
    Rhode\ Island South\ Carolina South\ Dakota Tennessee Texas Utah Vermont
    Virginia Washington West\ Virginia Wisconsin Wyoming
    Washington,\ D.C. District\ of\ Columbia Puerto\ Rico
  ]),
  'GB' => Set.new(%w[
    England Scotland Wales Northern\ Ireland
  ]),
  'CA' => Set.new(%w[
    Alberta British\ Columbia Manitoba New\ Brunswick
    Newfoundland\ and\ Labrador Northwest\ Territories Nova\ Scotia
    Nunavut Ontario Prince\ Edward\ Island Québec Quebec Saskatchewan Yukon
  ]),
  'AU' => Set.new(%w[
    New\ South\ Wales Victoria Queensland South\ Australia
    Western\ Australia Tasmania Northern\ Territory
    Australian\ Capital\ Territory
  ]),
  'NZ' => Set.new(%w[
    Auckland Waikato Bay\ of\ Plenty Gisborne Hawke's\ Bay
    Taranaki Manawatū-Whanganui Wellington Tasman Nelson
    Marlborough West\ Coast Canterbury Otago Southland
    Northland
  ])
}.freeze

# Also accept "United States", "United Kingdom", etc. as valid — but these
# are country-level, not useful as regions. Nil them out.
COUNTRY_NAMES = Set.new([
  'United States', 'United Kingdom', 'Canada', 'Australia', 'New Zealand',
  'United States of America', 'USA', 'UK', 'Great Britain'
]).freeze

def valid_region?(region, country)
  return false if region.nil? || region.empty?
  return false if COUNTRY_NAMES.include?(region)

  allowed = VALID_REGIONS[country]
  return false unless allowed

  allowed.include?(region)
end

seed_dir = ARGV[0] || 'db/seeds/musicbrainz'

files = Dir[File.join(seed_dir, 'bands_*.rb')].sort
if files.empty?
  puts "No band seed files found in #{seed_dir}"
  exit 1
end

total_fixed = 0
total_region_cleared = 0
total_region_to_city = 0

files.each do |filepath|
  content = File.read(filepath)
  changes = 0

  # Match each band hash line and fix city/region
  fixed_content = content.gsub(/^(\s*\{.*?\}),?$/) do |line|
    original = line

    # Extract country
    country_match = line.match(/country: "([^"]*)"/)
    country = country_match&.[](1)

    # Extract city
    city_match = line.match(/city: (?:"([^"]*)"|nil)/)
    city = city_match&.[](1)

    # Extract region
    region_match = line.match(/region: (?:"([^"]*)"|nil)/)
    region = region_match&.[](1)

    next line unless country

    new_city = city
    new_region = region

    if region && !valid_region?(region, country)
      if city.nil? || city.empty?
        # Region is actually a city — move it
        new_city = region
        new_region = nil
        total_region_to_city += 1
      elsif city == region
        # Duplicate — clear region
        new_region = nil
        total_region_cleared += 1
      else
        # Region is a city but we already have a city — just clear region
        new_region = nil
        total_region_cleared += 1
      end
    elsif region && city == region
      # Both are a valid region name (e.g., city="New York", region="New York")
      # Keep region, clear city since it's state-level, not a specific city
      new_city = nil
      total_region_cleared += 1
    end

    if new_city != city || new_region != region
      changes += 1
      city_val = new_city ? "\"#{new_city}\"" : 'nil'
      region_val = new_region ? "\"#{new_region}\"" : 'nil'
      line = line.sub(/city: (?:"[^"]*"|nil)/, "city: #{city_val}")
      line = line.sub(/region: (?:"[^"]*"|nil)/, "region: #{region_val}")
    end

    line
  end

  if changes > 0
    File.write(filepath, fixed_content)
    puts "Fixed #{filepath}: #{changes} records updated"
    total_fixed += changes
  else
    puts "No changes needed: #{filepath}"
  end
end

puts ""
puts "Done!"
puts "Total records fixed: #{total_fixed}"
puts "  Regions cleared (was a city name): #{total_region_cleared}"
puts "  Regions moved to city (city was nil): #{total_region_to_city}"
