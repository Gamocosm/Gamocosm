require "application_system_test_case"

class VolumesTest < ApplicationSystemTestCase
  setup do
    @volume = volumes(:one)
  end

  test "visiting the index" do
    visit volumes_url
    assert_selector "h1", text: "Volumes"
  end

  test "creating a Volume" do
    visit volumes_url
    click_on "New Volume"

    fill_in "Remote", with: @volume.remote_id
    fill_in "Remote region slug", with: @volume.remote_region_slug
    fill_in "Remote size gb", with: @volume.remote_size_gb
    fill_in "Remote snapshot", with: @volume.remote_snapshot_id
    click_on "Create Volume"

    assert_text "Volume was successfully created"
    click_on "Back"
  end

  test "updating a Volume" do
    visit volumes_url
    click_on "Edit", match: :first

    fill_in "Remote", with: @volume.remote_id
    fill_in "Remote region slug", with: @volume.remote_region_slug
    fill_in "Remote size gb", with: @volume.remote_size_gb
    fill_in "Remote snapshot", with: @volume.remote_snapshot_id
    click_on "Update Volume"

    assert_text "Volume was successfully updated"
    click_on "Back"
  end

  test "destroying a Volume" do
    visit volumes_url
    page.accept_confirm do
      click_on "Destroy", match: :first
    end

    assert_text "Volume was successfully destroyed"
  end
end
