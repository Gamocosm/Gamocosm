#!/usr/bin/env -S rails runner

puts JSON.pretty_generate({
  regions: Gamocosm.digital_ocean.region_list_uncached.map(&:values),
  sizes: Gamocosm.digital_ocean.size_list_uncached.map(&:values),
})
