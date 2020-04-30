json.extract! volume, :id, :remote_id, :remote_size_gb, :remote_region_slug, :remote_snapshot_id, :created_at, :updated_at
json.url volume_url(volume, format: :json)
