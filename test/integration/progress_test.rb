require 'integration_test_helper'

class GuideProgressTest < ActionDispatch::IntegrationTest

  test "should update progress of a guide" do
    without_metadata_denormalisation Guide do

      stub_request(:get, "http://panopticon.test.gov.uk/artefacts/2356.js").
        to_return(status: 200, body: "{}", headers: {})

      # This isn't right, really need a way to run actions when
      # logged in as particular users without having Signonotron running.
      #
      FactoryGirl.create :user

      guide = FactoryGirl.create(:guide, panopticon_id: 2356)

      visit "/admin/guides/#{guide.to_param}"

      click_on 'Untitled part'
      within :css, '#parts div.part:first-of-type' do
        fill_in 'Title', with: 'Part One'
        fill_in 'Body',  with: 'Body text'
        fill_in 'Slug',  with: 'part-one'
      end
      click_on "Save"

      click_on "Fact check"

      within "#request_fact_check_form" do
        fill_in "Comment",       with: "Blah"
        fill_in "Email address", with: "user@example.com"
        click_on "Save"
      end

      wait_until { page.has_content? "Status: Fact check requested" }

      guide.reload

      assert guide.editions.first.status_is?(Action::FACT_CHECK_REQUESTED)
    end
  end
end
