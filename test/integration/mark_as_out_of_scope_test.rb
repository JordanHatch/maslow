# encoding: UTF-8
require_relative '../integration_test_helper'

class MarkAsOutOfScopeTest < ActionDispatch::IntegrationTest
  def need_hash
    {
      "id" => "100001",
      "role" => "parent",
      "goal" => "apply for a primary school place",
      "benefit" => "my child can start school",
      "met_when" => ["win","awesome","more"],
      "organisations" => [],
      "legislation" => "Blank Fields Act 2013",
      "revisions" => [],
      "applies_to_all_organisations" => false
    }
  end

  setup do
    login_as_stub_admin
    need_api_has_organisations(
      "committee-on-climate-change" => "Committee on Climate Change",
      "competition-commission" => "Competition Commission",
      "ministry-of-justice" => "Ministry of Justice"
    )
  end

  context "marking a need as out of scope" do
    setup do
      @need = need_hash.merge(
        "status" => {
          "description" => "proposed",
        },
      )
      need_api_has_needs([@need]) # For need list
      content_api_has_artefacts_for_need_id("100001", [])

      @api_url = Plek.current.find('need-api') + '/needs/100001'
    end

    should "be able to mark a need as out of scope" do
      need_api_has_need(@need) # For individual need

      request_body = blank_need_request.merge(
        "role" => "parent",
        "goal" => "apply for a primary school place",
        "benefit" => "my child can start school",
        "legislation" => "Blank Fields Act 2013",
        "met_when" => ["win","awesome","more"],
        "status" => {
          "description" => "not valid",
          "reasons" => [ "the need is not in scope for GOV.UK because whitespace is not acceptable" ],
        },
        "author" => {
          "name" => stub_user.name,
          "email" => stub_user.email,
          "uid" => stub_user.uid
        }
      )
      request = stub_request(:put, @api_url).with(:body => request_body.to_json)

      visit "/needs"
      click_on "100001"
      click_on "Actions"

      # There are two 'Record validity decision' buttons
      # The second is a confirmation modal drop down when JavaScript is on
      # The first is an action initiator in the header
      within "#workflow #record-validity-decision" do
        click_on "Record validity decision"
      end

      within ".non-js-form" do
        # This is a confirmation on a separate page when JavaScript is off
        fill_in "Why is this need out of scope?", with: "whitespace is not acceptable"
        click_on "Update the status"
      end

      assert page.has_content?("Need has been marked as out of scope")
    end

    should "show an error message if there's a problem marking a need as out of scope" do
      need_api_has_need(@need) # For individual need
      request = stub_request(:put, @api_url).to_return(status: 422)

      visit "/needs"
      click_on "100001"
      click_on "Actions"

      within "#workflow #record-validity-decision" do
        click_on "Record validity decision"
      end

      within ".non-js-form" do
        fill_in "Why is this need out of scope?", with: "foo"
        click_on "Update the status"
      end

      assert page.has_content?("We had a problem marking the need as out of scope")
    end

    should "show an error message if there is no reason why the need is out of scope" do
      need_api_has_need(@need) # For individual need

      visit "/needs"
      click_on "100001"
      click_on "Actions"

      within "#workflow #record-validity-decision" do
        click_on "Record validity decision"
      end

      within ".non-js-form" do
        click_on "Update the status"
      end

      assert page.has_content?("A reason is required to mark a need as out of scope")
    end
  end

  context "Need is already out of scope" do
    setup do
      @need = need_hash.merge(
        "status" => {
          "description" => "not valid",
          "reasons" => [ "some reason" ],
        }
      )
      need_api_has_needs([@need]) # For need list
      content_api_has_artefacts_for_need_id("100001", [])

      @api_url = Plek.current.find('need-api') + '/needs/100001'
    end

    should "have 'Mark as out of scope' disabled" do
      need_api_has_need(@need) # For individual need

      visit "/needs"
      click_on "100001"
      click_on "Actions"

      assert page.has_selector?("a[id=out-of-scope][disabled]")
    end
  end
end
